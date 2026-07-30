CLASS zcl_fi_rev_bg_op DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_bgmc_op_single_tx_uncontr.

    METHODS constructor
      IMPORTING
        iv_request_uuid TYPE sysuuid_x16.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_reverse_result,
        success       TYPE abap_bool,
        object_type   TYPE bapiache09-obj_type,
        object_key    TYPE bapiache09-obj_key,
        object_system TYPE bapiache09-obj_sys,
        message       TYPE bapiret2,
      END OF ty_reverse_result.

    DATA mv_request_uuid TYPE sysuuid_x16.

    METHODS has_error
      IMPORTING
        is_return          TYPE bapiret2 OPTIONAL
        it_return          TYPE zif_fi_rev_proxy=>tt_return OPTIONAL
      RETURNING
        VALUE(rv_has_error) TYPE abap_bool.

    METHODS select_message
      IMPORTING
        is_return       TYPE bapiret2 OPTIONAL
        it_return       TYPE zif_fi_rev_proxy=>tt_return OPTIONAL
      RETURNING
        VALUE(rs_return) TYPE bapiret2.

    METHODS reverse_one
      IMPORTING
        io_proxy        TYPE REF TO zif_fi_rev_proxy
        iv_company_code TYPE bukrs
        iv_fiscal_year  TYPE gjahr
        iv_document     TYPE belnr_d
        iv_reason       TYPE stgrd
        iv_posting_date TYPE budat
        iv_period       TYPE monat
        iv_bus_act      TYPE bapiache09-bus_act
      RETURNING
        VALUE(rs_result) TYPE ty_reverse_result.

    METHODS update_header
      IMPORTING
        iv_status        TYPE ztfi_rev_req-processing_status
        is_message       TYPE bapiret2 OPTIONAL
        is_result        TYPE ty_reverse_result OPTIONAL.

    METHODS update_item
      IMPORTING
        iv_item_number TYPE ztfi_rev_itm-item_number
        iv_status      TYPE ztfi_rev_itm-processing_status
        is_message     TYPE bapiret2 OPTIONAL
        is_result      TYPE ty_reverse_result OPTIONAL.
ENDCLASS.


CLASS zcl_fi_rev_bg_op IMPLEMENTATION.

  METHOD constructor.
    mv_request_uuid = iv_request_uuid.
  ENDMETHOD.


  METHOD has_error.
    rv_has_error = xsdbool(
      is_return-type CA 'AEX'
      OR line_exists( it_return[ type = 'A' ] )
      OR line_exists( it_return[ type = 'E' ] )
      OR line_exists( it_return[ type = 'X' ] )
    ).
  ENDMETHOD.


  METHOD select_message.
    LOOP AT it_return ASSIGNING FIELD-SYMBOL(<message>)
      WHERE type CA 'AEX'.
      rs_return = <message>.
      RETURN.
    ENDLOOP.

    IF is_return-type IS NOT INITIAL
       OR is_return-message IS NOT INITIAL.
      rs_return = is_return.
      RETURN.
    ENDIF.

    READ TABLE it_return INDEX 1 INTO rs_return.
  ENDMETHOD.


  METHOD reverse_one.
    DATA lt_return TYPE zif_fi_rev_proxy=>tt_return.

    DATA(ls_reversal) = VALUE bapiacrev(
      comp_code  = iv_company_code
      ac_doc_no  = iv_document
      fisc_year  = iv_fiscal_year
      reason_rev = iv_reason
      pstng_date = iv_posting_date
      fis_period = iv_period
    ).

    io_proxy->reverse_document(
      EXPORTING
        is_reversal      = ls_reversal
        iv_bus_act       = iv_bus_act
      IMPORTING
        ev_object_type   = rs_result-object_type
        ev_object_key    = rs_result-object_key
        ev_object_system = rs_result-object_system
      CHANGING
        ct_return        = lt_return
    ).

    IF has_error( it_return = lt_return ) = abap_true.
      io_proxy->rollback_work( ).
      rs_result-message = select_message( it_return = lt_return ).
      RETURN.
    ENDIF.

    DATA(ls_commit_return) = io_proxy->commit_work( ).

    IF has_error( is_return = ls_commit_return ) = abap_true.
      rs_result-message = ls_commit_return.
      RETURN.
    ENDIF.

    rs_result-success = abap_true.
    rs_result-message = select_message( it_return = lt_return ).

    IF rs_result-message-type IS INITIAL.
      rs_result-message = VALUE #(
        type    = 'S'
        message = |Document { iv_company_code }/{ iv_fiscal_year }/{ iv_document } was reversed.|
      ).
    ENDIF.
  ENDMETHOD.


  METHOD update_header.
    DATA lv_timestamp TYPE timestampl.
    GET TIME STAMP FIELD lv_timestamp.

    UPDATE ztfi_rev_req
      SET processing_status      = @iv_status,
          reversal_object_type   = @is_result-object_type,
          reversal_object_key    = @is_result-object_key,
          reversal_object_system = @is_result-object_system,
          message_type           = @is_message-type,
          message_id             = @is_message-id,
          message_number         = @is_message-number,
          message_text           = @is_message-message,
          last_changed_by        = @sy-uname,
          last_changed_at        = @lv_timestamp
      WHERE request_uuid = @mv_request_uuid.
  ENDMETHOD.


  METHOD update_item.
    DATA lv_timestamp TYPE timestampl.
    GET TIME STAMP FIELD lv_timestamp.

    UPDATE ztfi_rev_itm
      SET processing_status               = @iv_status,
          clearing_rev_object_type   = @is_result-object_type,
          clearing_rev_object_key    = @is_result-object_key,
          clearing_rev_object_system = @is_result-object_system,
          message_type                    = @is_message-type,
          message_id                      = @is_message-id,
          message_number                  = @is_message-number,
          message_text                    = @is_message-message,
          last_changed_by                 = @sy-uname,
          last_changed_at                 = @lv_timestamp
      WHERE request_uuid = @mv_request_uuid
        AND item_number  = @iv_item_number.
  ENDMETHOD.


  METHOD if_bgmc_op_single_tx_uncontr~execute.
    SELECT SINGLE FROM ztfi_rev_req
      FIELDS *
      WHERE request_uuid = @mv_request_uuid
      INTO @DATA(ls_request).

    IF sy-subrc <> 0.
      RAISE EXCEPTION NEW cx_bgmc_operation( ).
    ENDIF.

    IF ls_request-processing_status = 'COMPLETED'.
      RETURN.
    ENDIF.

    SELECT FROM ztfi_rev_itm
      FIELDS *
      WHERE request_uuid = @mv_request_uuid
      ORDER BY item_number
      INTO TABLE @DATA(lt_items).

    update_header( iv_status = 'VALIDATING' ).

    SELECT SINGLE FROM bkpf
      FIELDS awtyp, stblg, stjah
      WHERE bukrs = @ls_request-company_code
        AND belnr = @ls_request-document_number
        AND gjahr = @ls_request-fiscal_year
      INTO @DATA(ls_source_document).

    IF sy-subrc <> 0.
      DATA(ls_not_found) = VALUE bapiret2(
        type    = 'E'
        message = 'The original accounting document was not found.'
      ).
      update_header(
        iv_status  = 'VALIDATION_FAILED'
        is_message = ls_not_found
      ).
      RETURN.
    ENDIF.

    IF ls_source_document-stblg IS NOT INITIAL.
      DATA(ls_already_reversed) = VALUE bapiret2(
        type    = 'S'
        message = |The document is already reversed by { ls_source_document-stblg }/{ ls_source_document-stjah }.|
      ).
      update_header(
        iv_status  = 'COMPLETED'
        is_message = ls_already_reversed
      ).
      RETURN.
    ENDIF.

    "FI-AA documents must be reversed in Asset Accounting. Add an
    "origin-specific adapter before enabling those documents.
    IF ls_request-document_origin = 'FI_AA'
       OR ls_source_document-awtyp = 'AMBU'.
      DATA(ls_unsupported_origin) = VALUE bapiret2(
        type    = 'E'
        message = 'FI-AA source documents require an Asset Accounting reversal adapter.'
      ).
      update_header(
        iv_status  = 'UNSUPPORTED_ORIGIN'
        is_message = ls_unsupported_origin
      ).
      RETURN.
    ENDIF.

    IF ls_request-reset_clearing = abap_true
       AND lt_items IS INITIAL.
      DATA(ls_no_clearing_items) = VALUE bapiret2(
        type    = 'E'
        message = 'At least one clearing item is required when ResetClearing is selected.'
      ).
      update_header(
        iv_status  = 'VALIDATION_FAILED'
        is_message = ls_no_clearing_items
      ).
      RETURN.
    ENDIF.

    IF ls_request-test_run = abap_true.
      DATA(ls_validated) = VALUE bapiret2(
        type    = 'S'
        message = 'Validation completed. No document was changed because TestRun is selected.'
      ).
      update_header(
        iv_status  = 'VALIDATED'
        is_message = ls_validated
      ).
      RETURN.
    ENDIF.

    DATA(lo_proxy) = zcl_fi_rev_factory=>create_instance( ).

    IF ls_request-reset_clearing = abap_true.
      update_header( iv_status = 'RESETTING_CLEARING' ).

      LOOP AT lt_items ASSIGNING FIELD-SYMBOL(<item>).
        IF <item>-processing_status = 'COMPLETED'.
          CONTINUE.
        ENDIF.

        update_item(
          iv_item_number = <item>-item_number
          iv_status      = 'RESETTING_CLEARING'
        ).

        DATA(ls_reset_return) = lo_proxy->reset_clearing(
          iv_company_code      = <item>-clearing_company_code
          iv_fiscal_year       = <item>-clearing_fiscal_year
          iv_clearing_document = <item>-clearing_document
        ).

        IF has_error( is_return = ls_reset_return ) = abap_true.
          lo_proxy->rollback_work( ).
          update_item(
            iv_item_number = <item>-item_number
            iv_status      = 'RESET_FAILED'
            is_message     = ls_reset_return
          ).
          update_header(
            iv_status  = 'RESET_FAILED'
            is_message = ls_reset_return
          ).
          RETURN.
        ENDIF.

        DATA(ls_reset_commit) = lo_proxy->commit_work( ).

        IF has_error( is_return = ls_reset_commit ) = abap_true.
          update_item(
            iv_item_number = <item>-item_number
            iv_status      = 'RESET_FAILED'
            is_message     = ls_reset_commit
          ).
          update_header(
            iv_status  = 'RESET_FAILED'
            is_message = ls_reset_commit
          ).
          RETURN.
        ENDIF.

        IF ls_request-reverse_clearing_document = abap_true.
          update_item(
            iv_item_number = <item>-item_number
            iv_status      = 'REVERSING_CLEARING'
          ).

          DATA(ls_clearing_reversal) = reverse_one(
            io_proxy        = lo_proxy
            iv_company_code = <item>-clearing_company_code
            iv_fiscal_year  = <item>-clearing_fiscal_year
            iv_document     = <item>-clearing_document
            iv_reason       = ls_request-reversal_reason
            iv_posting_date = ls_request-reversal_posting_date
            iv_period       = ls_request-reversal_period
            iv_bus_act      = COND #(
              WHEN ls_request-business_transaction IS INITIAL
              THEN 'RFBU'
              ELSE ls_request-business_transaction
            )
          ).

          IF ls_clearing_reversal-success <> abap_true.
            update_item(
              iv_item_number = <item>-item_number
              iv_status      = 'REVERSAL_FAILED'
              is_message     = ls_clearing_reversal-message
            ).
            update_header(
              iv_status  = 'CLEARING_REV_FAILED'
              is_message = ls_clearing_reversal-message
            ).
            RETURN.
          ENDIF.

          update_item(
            iv_item_number = <item>-item_number
            iv_status      = 'COMPLETED'
            is_message     = ls_clearing_reversal-message
            is_result      = ls_clearing_reversal
          ).
        ELSE.
          update_item(
            iv_item_number = <item>-item_number
            iv_status      = 'COMPLETED'
            is_message     = ls_reset_return
          ).
        ENDIF.
      ENDLOOP.
    ENDIF.

    IF ls_request-reverse_original_document = abap_true.
      update_header( iv_status = 'REVERSING' ).

      DATA(ls_original_reversal) = reverse_one(
        io_proxy        = lo_proxy
        iv_company_code = ls_request-company_code
        iv_fiscal_year  = ls_request-fiscal_year
        iv_document     = ls_request-document_number
        iv_reason       = ls_request-reversal_reason
        iv_posting_date = ls_request-reversal_posting_date
        iv_period       = ls_request-reversal_period
        iv_bus_act      = COND #(
          WHEN ls_request-business_transaction IS INITIAL
          THEN 'RFBU'
          ELSE ls_request-business_transaction
        )
      ).

      IF ls_original_reversal-success <> abap_true.
        update_header(
          iv_status  = 'REVERSAL_FAILED'
          is_message = ls_original_reversal-message
        ).
        RETURN.
      ENDIF.

      update_header(
        iv_status  = 'COMPLETED'
        is_message = ls_original_reversal-message
        is_result  = ls_original_reversal
      ).
    ELSE.
      DATA(ls_completed) = VALUE bapiret2(
        type    = 'S'
        message = 'The requested clearing reset steps were completed.'
      ).
      update_header(
        iv_status  = 'COMPLETED'
        is_message = ls_completed
      ).
    ENDIF.
  ENDMETHOD.

ENDCLASS.
