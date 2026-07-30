INTERFACE zif_fi_rev_proxy
  PUBLIC.

  TYPES tt_return TYPE STANDARD TABLE OF bapiret2
    WITH EMPTY KEY.

  METHODS reset_clearing
    IMPORTING
      iv_company_code      TYPE bukrs
      iv_fiscal_year       TYPE gjahr
      iv_clearing_document TYPE belnr_d
    RETURNING
      VALUE(rs_return)     TYPE bapiret2.

  METHODS reverse_document
    IMPORTING
      is_reversal      TYPE bapiacrev
      iv_bus_act       TYPE bapiache09-bus_act DEFAULT 'RFBU'
    EXPORTING
      ev_object_type   TYPE bapiache09-obj_type
      ev_object_key    TYPE bapiache09-obj_key
      ev_object_system TYPE bapiache09-obj_sys
    CHANGING
      ct_return        TYPE tt_return.

  METHODS commit_work
    RETURNING
      VALUE(rs_return) TYPE bapiret2.

  METHODS rollback_work
    RETURNING
      VALUE(rs_return) TYPE bapiret2.

ENDINTERFACE.
