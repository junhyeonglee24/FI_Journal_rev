@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'FI Reversal Request'
@Metadata.allowExtensions: true

define root view entity ZI_FI_REV_REQ
  as select from ztfi_rev_req

  composition [0..*] of ZI_FI_REV_ITM as _Items
{
  key request_uuid               as RequestUUID,

      external_request_id        as ExternalRequestId,
      processing_status          as ProcessingStatus,

      company_code               as CompanyCode,
      fiscal_year                as FiscalYear,
      document_number            as DocumentNumber,
      document_origin            as DocumentOrigin,

      reversal_reason            as ReversalReason,
      reversal_posting_date      as ReversalPostingDate,
      reversal_period            as ReversalPeriod,
      business_transaction       as BusinessTransaction,

      reset_clearing             as ResetClearing,
      reverse_clearing_document  as ReverseClearingDocument,
      reverse_original_document  as ReverseOriginalDocument,
      test_run                   as TestRun,
      destination                as Destination,
      header_text                as HeaderText,

      reversal_object_type       as ReversalObjectType,
      reversal_object_key        as ReversalObjectKey,
      reversal_object_system     as ReversalObjectSystem,

      message_type               as MessageType,
      message_id                 as MessageId,
      message_number             as MessageNumber,
      message_text               as MessageText,

      created_by                 as CreatedBy,
      created_at                 as CreatedAt,
      last_changed_by            as LastChangedBy,
      last_changed_at            as LastChangedAt,

      _Items
}
