CLASS zcl_fi_rev_factory DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.
    CLASS-METHODS create_instance
      RETURNING
        VALUE(ro_proxy) TYPE REF TO zif_fi_rev_proxy.
ENDCLASS.


CLASS zcl_fi_rev_factory IMPLEMENTATION.
  METHOD create_instance.
    ro_proxy = NEW zcl_fi_rev_proxy( ).
  ENDMETHOD.
ENDCLASS.
