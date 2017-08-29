unit contextCode;

interface

const
  LCX_NULL = $0;
  LCX_HEAP = $1;
  LCX_CLUSTERED = $2;
  LCX_INDEX_LEAF = $3;
  LCX_INDEX_INTERIOR = $4;
  LCX_TEXT_MIX = $5;
  LCX_TEXT_TREE = $6;
  LCX_DIAGNOSTICS = $7;
  LCX_GAM = $8;
  LCX_SGAM = $9;
  LCX_IAM = $A;
  LCX_PFS = $B;
  LCX_IDENTITY_VALUE = $C;
  LCX_OBJECT_ID = $D;
  LCX_NONSYS_SPLIT = $E;
  LCX_FILE_HEADER = $11;
  LCX_SCHEMA_VERSION = $12;
  LCX_MARK_AS_GHOST = $13;
  LCX_BOOT_PAGE = $14;
  LCX_SYSCONFIG_PAGE = $15;
  LCX_BOOT_PAGE_CKPT = $17;
  LCX_DIFF_MAP = $18;
  LCX_ML_MAP = $19;
  LCX_REMOVE_VERSION_INFO = $1A;
  LCX_DBCC_FORMATTED = $1B;
  LCX_UNLINKED_REORG_PAGE = $1C;
  LCX_BULK_OPERATION_PAGE = $1D;
  LCX_TRACKED_XDES = $1E;
  LCX_ENCRYPT_UNALLOC_PAGE = $1F;
  LCX_SORT_PAGE = $20;
  LCX_WORK_FILE_PAGE = $21;
  LCX_RESTORE_BAD_UNALLOC_PAGE = $22;

implementation

function contextCodeToStr(val: Integer): string;
begin
  case val of
    LCX_NULL:
      result := 'LCX_NULL';
    LCX_HEAP:
      result := 'LCX_HEAP';
    LCX_CLUSTERED:
      result := 'LCX_CLUSTERED';
    LCX_INDEX_LEAF:
      result := 'LCX_INDEX_LEAF';
    LCX_INDEX_INTERIOR:
      result := 'LCX_INDEX_INTERIOR';
    LCX_TEXT_MIX:
      result := 'LCX_TEXT_MIX';
    LCX_TEXT_TREE:
      result := 'LCX_TEXT_TREE';
    LCX_DIAGNOSTICS:
      result := 'LCX_DIAGNOSTICS';
    LCX_GAM:
      result := 'LCX_GAM';
    LCX_SGAM:
      result := 'LCX_SGAM';
    LCX_IAM:
      result := 'LCX_IAM';
    LCX_PFS:
      result := 'LCX_PFS';
    LCX_IDENTITY_VALUE:
      result := 'LCX_IDENTITY_VALUE';
    LCX_OBJECT_ID:
      result := 'LCX_OBJECT_ID';
    LCX_NONSYS_SPLIT:
      result := 'LCX_NONSYS_SPLIT';
    LCX_FILE_HEADER:
      result := 'LCX_FILE_HEADER';
    LCX_SCHEMA_VERSION:
      result := 'LCX_SCHEMA_VERSION';
    LCX_MARK_AS_GHOST:
      result := 'LCX_MARK_AS_GHOST';
    LCX_BOOT_PAGE:
      result := 'LCX_BOOT_PAGE';
    LCX_SYSCONFIG_PAGE:
      result := 'LCX_SYSCONFIG_PAGE';
    LCX_BOOT_PAGE_CKPT:
      result := 'LCX_BOOT_PAGE_CKPT';
    LCX_DIFF_MAP:
      result := 'LCX_DIFF_MAP';
    LCX_ML_MAP:
      result := 'LCX_ML_MAP';
    LCX_REMOVE_VERSION_INFO:
      result := 'LCX_REMOVE_VERSION_INFO';
    LCX_DBCC_FORMATTED:
      result := 'LCX_DBCC_FORMATTED';
    LCX_UNLINKED_REORG_PAGE:
      result := 'LCX_UNLINKED_REORG_PAGE';
    LCX_BULK_OPERATION_PAGE:
      result := 'LCX_BULK_OPERATION_PAGE';
    LCX_TRACKED_XDES:
      result := 'LCX_TRACKED_XDES';
    LCX_ENCRYPT_UNALLOC_PAGE:
      result := 'LCX_ENCRYPT_UNALLOC_PAGE';
    LCX_SORT_PAGE:
      result := 'LCX_SORT_PAGE';
    LCX_WORK_FILE_PAGE:
      result := 'LCX_WORK_FILE_PAGE';
    LCX_RESTORE_BAD_UNALLOC_PAGE:
      result := 'LCX_RESTORE_BAD_UNALLOC_PAGE';
  end;
end;

end.

