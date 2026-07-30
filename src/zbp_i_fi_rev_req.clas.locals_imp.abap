CLASS lcl_rev_buffer DEFINITION
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.
    TYPES:
      BEGIN OF ty_cid_map,
        cid          TYPE abp_behv_cid,
        request_uuid TYPE sysuuid_x16,
      END OF ty_cid_map.

    CLASS-DATA gt_requests TYPE STANDARD TABLE OF ztfi_rev_req
      WITH EMPTY KEY.

    CLASS-DATA gt_items TYPE STANDARD TABLE OF ztfi_rev_itm
      WITH EMPTY KEY.

    CLASS-DATA gt_cid_map TYPE HASHED TABLE OF ty_cid_map
      WITH UNIQUE KEY cid.
ENDCLASS.

CLASS lcl_rev_buffer IMPLEMENTATION.
ENDCLASS.


CLASS lhc_Request DEFINITION
  INHERITING FROM cl_abap_behavior_handler.

  PRIVATE SECTION.
    METHODS get_instance_authorizations
      FOR INSTANCE AUTHORIZATION
      IMPORTING
        keys
        REQUEST requested_authorizations
        FOR Request
      RESULT result.

    METHODS create
      FOR MODIFY
      IMPORTING entities FOR CREATE Request.

    METHODS cba_Items
      FOR MODIFY
      IMPORTING entities_cba
      FOR CREATE Request\_Items.

    METHODS read
      FOR READ
      IMPORTING keys FOR READ Request
      RESULT result.

    METHODS lock
      FOR LOCK
      IMPORTING keys FOR LOCK Request.
ENDCLASS.


CLASS lhc_Request IMPLEMENTATION.

  METHOD get_instance_authorizations.
    result = VALUE #(
      FOR key IN keys
      (
        %tky = key-%tky
      )
    ).
  ENDMETHOD.


  METHOD create.
    DATA lv_timestamp TYPE timestampl.
    GET TIME STAMP FIELD lv_timestamp.

    LOOP AT entities ASSIGNING FIELD-SYMBOL(<entity>).
      IF <entity>-ExternalRequestId IS INITIAL
         OR <entity>-CompanyCode IS INITIAL
         OR <entity>-FiscalYear IS INITIAL
         OR <entity>-DocumentNumber IS INITIAL
         OR <entity>-ReversalReason IS INITIAL
         OR <entity>-ReversalPostingDate IS INITIAL.
        APPEND VALUE #( %cid = <entity>-%cid ) TO failed-Request.
        APPEND VALUE #(
          %cid = <entity>-%cid
          %msg = new_message_with_text(
            severity = if_abap_behv_message=>severity-error
            text     = 'Enter the external ID, source document, reversal reason, and posting date.'
          )
        ) TO reported-Request.
        CONTINUE.
      ENDIF.

      IF <entity>-ReverseClearingDocument = abap_true
         AND <entity>-ResetClearing <> abap_true.
        APPEND VALUE #( %cid = <entity>-%cid ) TO failed-Request.
        APPEND VALUE #(
          %cid = <entity>-%cid
          %msg = new_message_with_text(
            severity = if_abap_behv_message=>severity-error
            text     = 'ResetClearing is required before reversing a clearing document.'
          )
        ) TO reported-Request.
        CONTINUE.
      ENDIF.

      IF <entity>-ResetClearing <> abap_true
         AND <entity>-ReverseOriginalDocument <> abap_true
         AND <entity>-TestRun <> abap_true.
        APPEND VALUE #( %cid = <entity>-%cid ) TO failed-Request.
        APPEND VALUE #(
          %cid = <entity>-%cid
          %msg = new_message_with_text(
            severity = if_abap_behv_message=>severity-error
            text     = 'Select ResetClearing, ReverseOriginalDocument, or TestRun.'
          )
        ) TO reported-Request.
        CONTINUE.
      ENDIF.

      READ TABLE lcl_rev_buffer=>gt_requests
        WITH KEY external_request_id = <entity>-ExternalRequestId
        TRANSPORTING NO FIELDS.

      IF sy-subrc = 0.
        APPEND VALUE #( %cid = <entity>-%cid ) TO failed-Request.
        APPEND VALUE #(
          %cid = <entity>-%cid
          %msg = new_message_with_text(
            severity = if_abap_behv_message=>severity-error
            text     = 'The external request ID is duplicated in the current RAP request.'
          )
        ) TO reported-Request.
        CONTINUE.
      ENDIF.

      SELECT SINGLE FROM ztfi_rev_req
        FIELDS request_uuid
        WHERE external_request_id = @<entity>-ExternalRequestId
        INTO @DATA(lv_existing_uuid).

      IF sy-subrc = 0.
        APPEND VALUE #( %cid = <entity>-%cid ) TO failed-Request.
        APPEND VALUE #(
          %cid = <entity>-%cid
          %msg = new_message_with_text(
            severity = if_abap_behv_message=>severity-error
            text     = 'The external request ID has already been submitted.'
          )
        ) TO reported-Request.
        CONTINUE.
      ENDIF.

      TRY.
          DATA(lv_request_uuid) =
            cl_system_uuid=>create_uuid_x16_static( ).
        CATCH cx_uuid_error INTO DATA(lx_uuid).
          APPEND VALUE #( %cid = <entity>-%cid ) TO failed-Request.
          APPEND VALUE #(
            %cid = <entity>-%cid
            %msg = new_message_with_text(
              severity = if_abap_behv_message=>severity-error
              text     = lx_uuid->get_text( )
            )
          ) TO reported-Request.
          CONTINUE.
      ENDTRY.

      APPEND VALUE #(
        client                     = sy-mandt
        request_uuid               = lv_request_uuid
        external_request_id        = <entity>-ExternalRequestId
        processing_status          = 'ACCEPTED'
        company_code               = <entity>-CompanyCode
        fiscal_year                = <entity>-FiscalYear
        document_number            = <entity>-DocumentNumber
        document_origin            = COND #(
          WHEN <entity>-DocumentOrigin IS INITIAL
          THEN 'FI'
          ELSE <entity>-DocumentOrigin
        )
        reversal_reason            = <entity>-ReversalReason
        reversal_posting_date      = <entity>-ReversalPostingDate
        reversal_period            = <entity>-ReversalPeriod
        business_transaction       = COND #(
          WHEN <entity>-BusinessTransaction IS INITIAL
          THEN 'RFBU'
          ELSE <entity>-BusinessTransaction
        )
        reset_clearing             = <entity>-ResetClearing
        reverse_clearing_document  = <entity>-ReverseClearingDocument
        reverse_original_document  = <entity>-ReverseOriginalDocument
        test_run                   = <entity>-TestRun
        destination                = <entity>-Destination
        header_text                = <entity>-HeaderText
        created_by                 = sy-uname
        created_at                 = lv_timestamp
        last_changed_by            = sy-uname
        last_changed_at            = lv_timestamp
      ) TO lcl_rev_buffer=>gt_requests.

      IF <entity>-%cid IS NOT INITIAL.
        INSERT VALUE #(
          cid          = <entity>-%cid
          request_uuid = lv_request_uuid
        ) INTO TABLE lcl_rev_buffer=>gt_cid_map.
      ENDIF.

      APPEND VALUE #(
        %cid        = <entity>-%cid
        RequestUUID = lv_request_uuid
      ) TO mapped-Request.

      APPEND VALUE #(
        %cid = <entity>-%cid
        %msg = new_message_with_text(
          severity = if_abap_behv_message=>severity-information
          text     = 'The FI reversal request was accepted.'
        )
      ) TO reported-Request.
    ENDLOOP.
  ENDMETHOD.


  METHOD cba_Items.
    DATA:
      lv_timestamp    TYPE timestampl,
      lv_request_uuid TYPE sysuuid_x16.

    GET TIME STAMP FIELD lv_timestamp.

    LOOP AT entities_cba ASSIGNING FIELD-SYMBOL(<parent>).
      CLEAR lv_request_uuid.

      IF <parent>-RequestUUID IS NOT INITIAL.
        lv_request_uuid = <parent>-RequestUUID.
      ELSEIF <parent>-%cid_ref IS NOT INITIAL.
        READ TABLE lcl_rev_buffer=>gt_cid_map
          WITH TABLE KEY cid = <parent>-%cid_ref
          ASSIGNING FIELD-SYMBOL(<cid_map>).
        IF sy-subrc = 0.
          lv_request_uuid = <cid_map>-request_uuid.
        ENDIF.
      ENDIF.

      LOOP AT <parent>-%target ASSIGNING FIELD-SYMBOL(<item>).
        IF lv_request_uuid IS INITIAL.
          APPEND VALUE #( %cid = <item>-%cid ) TO failed-Item.
          APPEND VALUE #(
            %cid = <item>-%cid
            %msg = new_message_with_text(
              severity = if_abap_behv_message=>severity-error
              text     = 'The parent reversal request was not found.'
            )
          ) TO reported-Item.
          CONTINUE.
        ENDIF.

        IF <item>-ItemNumber IS INITIAL
           OR <item>-ClearingCompanyCode IS INITIAL
           OR <item>-ClearingFiscalYear IS INITIAL
           OR <item>-ClearingDocument IS INITIAL.
          APPEND VALUE #( %cid = <item>-%cid ) TO failed-Item.
          APPEND VALUE #(
            %cid = <item>-%cid
            %msg = new_message_with_text(
              severity = if_abap_behv_message=>severity-error
              text     = 'Enter the item number and clearing document key.'
            )
          ) TO reported-Item.
          CONTINUE.
        ENDIF.

        READ TABLE lcl_rev_buffer=>gt_items
          WITH KEY
            request_uuid = lv_request_uuid
            item_number  = <item>-ItemNumber
          TRANSPORTING NO FIELDS.

        IF sy-subrc = 0.
          APPEND VALUE #( %cid = <item>-%cid ) TO failed-Item.
          APPEND VALUE #(
            %cid = <item>-%cid
            %msg = new_message_with_text(
              severity = if_abap_behv_message=>severity-error
              text     = |Item { <item>-ItemNumber } is duplicated.|
            )
          ) TO reported-Item.
          CONTINUE.
        ENDIF.

        APPEND VALUE #(
          client                = sy-mandt
          request_uuid          = lv_request_uuid
          item_number           = <item>-ItemNumber
          clearing_company_code = <item>-ClearingCompanyCode
          clearing_fiscal_year  = <item>-ClearingFiscalYear
          clearing_document     = <item>-ClearingDocument
          processing_status     = 'ACCEPTED'
          created_by            = sy-uname
          created_at            = lv_timestamp
          last_changed_by       = sy-uname
          last_changed_at       = lv_timestamp
        ) TO lcl_rev_buffer=>gt_items.

        APPEND VALUE #(
          %cid                = <item>-%cid
          RequestUUID         = lv_request_uuid
          ItemNumber          = <item>-ItemNumber
        ) TO mapped-Item.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.


  METHOD read.
    IF keys IS INITIAL.
      RETURN.
    ENDIF.

    SELECT FROM zi_fi_rev_req
      FIELDS *
      FOR ALL ENTRIES IN @keys
      WHERE RequestUUID = @keys-RequestUUID
      INTO CORRESPONDING FIELDS OF TABLE @result.
  ENDMETHOD.


  METHOD lock.
  ENDMETHOD.
ENDCLASS.


CLASS lsc_ZI_FI_REV_REQ DEFINITION
  INHERITING FROM cl_abap_behavior_saver_failed.

  PROTECTED SECTION.
    METHODS finalize REDEFINITION.
    METHODS check_before_save REDEFINITION.
    METHODS save REDEFINITION.
    METHODS cleanup REDEFINITION.
    METHODS cleanup_finalize REDEFINITION.
ENDCLASS.


CLASS lsc_ZI_FI_REV_REQ IMPLEMENTATION.

  METHOD finalize.
  ENDMETHOD.


  METHOD check_before_save.
  ENDMETHOD.


  METHOD save.
    LOOP AT lcl_rev_buffer=>gt_requests
      ASSIGNING FIELD-SYMBOL(<request>).

      TRY.
          INSERT ztfi_rev_req FROM @<request>.
        CATCH cx_sy_open_sql_db INTO DATA(lx_header_sql).
          APPEND VALUE #(
            %tky = VALUE #( RequestUUID = <request>-request_uuid )
          ) TO failed-Request.
          APPEND VALUE #(
            %tky = VALUE #( RequestUUID = <request>-request_uuid )
            %msg = new_message_with_text(
              severity = if_abap_behv_message=>severity-error
              text     = lx_header_sql->get_text( )
            )
          ) TO reported-Request.
          CONTINUE.
      ENDTRY.

      DATA(lv_item_save_failed) = abap_false.
      DATA(lv_item_error_text) = VALUE string( ).

      LOOP AT lcl_rev_buffer=>gt_items
        ASSIGNING FIELD-SYMBOL(<item>)
        WHERE request_uuid = <request>-request_uuid.
        TRY.
            INSERT ztfi_rev_itm FROM @<item>.
          CATCH cx_sy_open_sql_db INTO DATA(lx_item_sql).
            lv_item_save_failed = abap_true.
            lv_item_error_text = lx_item_sql->get_text( ).
            EXIT.
        ENDTRY.
      ENDLOOP.

      IF lv_item_save_failed = abap_true.
        DELETE FROM ztfi_rev_itm
          WHERE request_uuid = @<request>-request_uuid.
        DELETE FROM ztfi_rev_req
          WHERE request_uuid = @<request>-request_uuid.

        APPEND VALUE #(
          %tky = VALUE #( RequestUUID = <request>-request_uuid )
        ) TO failed-Request.
        APPEND VALUE #(
          %tky = VALUE #( RequestUUID = <request>-request_uuid )
          %msg = new_message_with_text(
            severity = if_abap_behv_message=>severity-error
            text     = lv_item_error_text
          )
        ) TO reported-Request.
        CONTINUE.
      ENDIF.

      TRY.
          cl_bgmc_process_factory=>get_default(
            )->create(
            )->set_name(
              |FI Reversal { <request>-company_code }/{ <request>-fiscal_year }/{ <request>-document_number }|
            )->set_operation_tx_uncontrolled(
              NEW zcl_fi_rev_bg_op(
                iv_request_uuid = <request>-request_uuid
              )
            )->save_for_execution( ).
        CATCH cx_bgmc INTO DATA(lx_bgmc).
          DELETE FROM ztfi_rev_itm
            WHERE request_uuid = @<request>-request_uuid.
          DELETE FROM ztfi_rev_req
            WHERE request_uuid = @<request>-request_uuid.

          APPEND VALUE #(
            %tky = VALUE #( RequestUUID = <request>-request_uuid )
          ) TO failed-Request.
          APPEND VALUE #(
            %tky = VALUE #( RequestUUID = <request>-request_uuid )
            %msg = new_message_with_text(
              severity = if_abap_behv_message=>severity-error
              text     = lx_bgmc->get_text( )
            )
          ) TO reported-Request.
      ENDTRY.
    ENDLOOP.
  ENDMETHOD.


  METHOD cleanup.
    CLEAR:
      lcl_rev_buffer=>gt_requests,
      lcl_rev_buffer=>gt_items,
      lcl_rev_buffer=>gt_cid_map.
  ENDMETHOD.


  METHOD cleanup_finalize.
    CLEAR:
      lcl_rev_buffer=>gt_requests,
      lcl_rev_buffer=>gt_items,
      lcl_rev_buffer=>gt_cid_map.
  ENDMETHOD.
ENDCLASS.
