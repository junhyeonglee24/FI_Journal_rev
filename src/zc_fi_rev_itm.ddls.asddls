@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'FI Reversal Clearing Item API'
@Metadata.allowExtensions: true

define view entity ZC_FI_REV_ITM
  as projection on ZI_FI_REV_ITM
{
  key RequestUUID,
  key ItemNumber,

      ClearingCompanyCode,
      ClearingFiscalYear,
      ClearingDocument,
      ProcessingStatus,
      ClearingReversalObjectType,
      ClearingReversalObjectKey,
      ClearingReversalObjectSystem,
      MessageType,
      MessageId,
      MessageNumber,
      MessageText,
      CreatedBy,
      CreatedAt,
      LastChangedBy,
      LastChangedAt,

      _Request : redirected to parent ZC_FI_REV_REQ
}
