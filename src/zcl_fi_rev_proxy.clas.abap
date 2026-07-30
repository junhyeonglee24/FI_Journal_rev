CLASS zcl_fi_rev_proxy DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE

  GLOBAL FRIENDS zcl_fi_rev_factory.

  PUBLIC SECTION.
    INTERFACES zif_fi_rev_proxy.

  PRIVATE SECTION.
    METHODS system_message
      RETURNING
        VALUE(rs_return) TYPE bapiret2.
ENDCLASS.


CLASS zcl_fi_rev_proxy IMPLEMENTATION.

  METHOD system_message.
    rs_return = VALUE #(
      type       = 'E'
      id         = sy-msgid
      number     = sy-msgno
      message_v1 = sy-msgv1
      message_v2 = sy-msgv2
      message_v3 = sy-msgv3
      message_v4 = sy-msgv4
    ).

    MESSAGE ID sy-msgid
      TYPE 'S'
      NUMBER sy-msgno
      WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4
      INTO rs_return-message.
  ENDMETHOD.


  METHOD zif_fi_rev_proxy~reset_clearing.
    "Classic API used by FBRA. Keep this call behind the port because
    "availability and release status differ by S/4HANA edition.
    CALL FUNCTION 'POSTING_INTERFACE_RESET_CLEAR'
      EXPORTING
        i_augbl = iv_clearing_document
        i_bukrs = iv_company_code
        i_gjahr = iv_fiscal_year
        i_tcode = 'FBRA'
      EXCEPTIONS
        OTHERS  = 1.

    IF sy-subrc = 0.
      rs_return = VALUE #(
        type    = 'S'
        message = |Clearing { iv_company_code }/{ iv_fiscal_year }/{ iv_clearing_document } was reset.|
      ).
    ELSE.
      rs_return = system_message( ).
      IF rs_return-message IS INITIAL.
        rs_return = VALUE #(
          type    = 'E'
          message = |Clearing reset failed with subrc { sy-subrc }.|
        ).
      ENDIF.
    ENDIF.
  ENDMETHOD.


  METHOD zif_fi_rev_proxy~reverse_document.
    CLEAR:
      ev_object_type,
      ev_object_key,
      ev_object_system,
      ct_return.

    CALL FUNCTION 'BAPI_ACC_DOCUMENT_REV_POST'
      EXPORTING
        reversal = is_reversal
        bus_act  = iv_bus_act
      IMPORTING
        obj_type = ev_object_type
        obj_key  = ev_object_key
        obj_sys  = ev_object_system
      TABLES
        return   = ct_return.
  ENDMETHOD.


  METHOD zif_fi_rev_proxy~commit_work.
    CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
      EXPORTING
        wait   = abap_true
      IMPORTING
        return = rs_return.
  ENDMETHOD.


  METHOD zif_fi_rev_proxy~rollback_work.
    CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'
      IMPORTING
        return = rs_return.
  ENDMETHOD.

ENDCLASS.
