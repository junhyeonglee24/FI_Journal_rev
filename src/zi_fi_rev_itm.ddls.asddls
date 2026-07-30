@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'FI Reversal Clearing Item'
@Metadata.allowExtensions: true

define view entity ZI_FI_REV_ITM
  as select from ztfi_rev_itm

  association to parent ZI_FI_REV_REQ as _Request
    on $projection.RequestUUID = _Request.RequestUUID
{
  key request_uuid                 as RequestUUID,
  key item_number                  as ItemNumber,

      clearing_company_code        as ClearingCompanyCode,
      clearing_fiscal_year         as ClearingFiscalYear,
      clearing_document            as ClearingDocument,
      processing_status            as ProcessingStatus,

      clearing_rev_object_type   as ClearingReversalObjectType,
      clearing_rev_object_key    as ClearingReversalObjectKey,
      clearing_rev_object_system as ClearingReversalObjectSystem,

      message_type                 as MessageType,
      message_id                   as MessageId,
      message_number               as MessageNumber,
      message_text                 as MessageText,

      created_by                   as CreatedBy,
      created_at                   as CreatedAt,
      last_changed_by              as LastChangedBy,
      last_changed_at              as LastChangedAt,

      _Request
}
