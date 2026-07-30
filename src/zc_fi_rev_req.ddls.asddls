@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'FI Reversal Request API'
@Metadata.allowExtensions: true

define root view entity ZC_FI_REV_REQ
  provider contract transactional_query
  as projection on ZI_FI_REV_REQ
{
  key RequestUUID,

      ExternalRequestId,
      ProcessingStatus,
      CompanyCode,
      FiscalYear,
      DocumentNumber,
      DocumentOrigin,
      ReversalReason,
      ReversalPostingDate,
      ReversalPeriod,
      BusinessTransaction,
      ResetClearing,
      ReverseClearingDocument,
      ReverseOriginalDocument,
      TestRun,
      Destination,
      HeaderText,
      ReversalObjectType,
      ReversalObjectKey,
      ReversalObjectSystem,
      MessageType,
      MessageId,
      MessageNumber,
      MessageText,
      CreatedBy,
      CreatedAt,
      LastChangedBy,
      LastChangedAt,

      _Items : redirected to composition child ZC_FI_REV_ITM
}
