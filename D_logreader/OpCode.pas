unit OpCode;

interface

const
  LOP_NULL = $0;
  LOP_FORMAT_PAGE = $1;
  LOP_INSERT_ROWS = $2;
  LOP_DELETE_ROWS = $3;
  LOP_MODIFY_ROW = $4;
  LOP_MODIFY_HEADER = $5;
  LOP_MODIFY_COLUMNS = $6;
  LOP_SET_BITS = $7;
  LOP_SET_FREE_SPACE = $A;
  LOP_DELETE_SPLIT = $B;
  LOP_UNDO_DELETE_SPLIT = $C;
  LOP_EXPUNGE_ROWS = $D;
  LOP_FILE_HDR_MODIFY = $10;
  LOP_CLEAR_GAM_BITS = $11;
  LOP_COUNT_DELTA = $12;
  LOP_ROOT_CHANGE = $13;
  LOP_COMPRESSION_INFO = $14;
  LOP_ENCRYPT_PAGE = $15;
  LOP_INSYSXACT = $16;
  LOP_REMOVE_VERSION_INFO = $7E;
  LOP_BEGIN_XACT = $80;
  LOP_COMMIT_XACT = $81;
  LOP_ABORT_XACT = $82;
  LOP_PREP_XACT = $83;
  LOP_MARK_SAVEPOINT = $84;
  LOP_FORGET_XACT = $85;
  LOP_CREATE_FILE = $86;
  LOP_DROP_FILE = $87;
  LOP_HOBT_DDL = $89;
  LOP_IDENT_NEWVAL = $8A;
  LOP_IDENT_SENTVAL = $8B;
  LOP_HOBT_DELTA = $8C;
  LOP_LOCK_XACT = $8D;
  LOP_CREATE_STREAMFILE = $8E;
  LOP_MIGRATE_LOCKS = $8F;
  LOP_DROP_STREAMFILE = $90;
  LOP_FS_DOWNLEVEL_OP = $91;
  LOP_MODIFY_STREAMFILE_HDR = $92;
  LOP_BP_DBVER = $94;
  LOP_COPY_VERSION_INFO = $95;
  LOP_BEGIN_CKPT = $96;
  LOP_XACT_CKPT = $98;
  LOP_END_CKPT = $99;
  LOP_BUF_WRITE = $9A;
  LOP_BEGIN_RECOVERY = $A0;
  LOP_END_RECOVERY = $A1;
  LOP_TENANT_LOG = $A2;
  LOP_FEDTM_INFO = $A6;
  LOP_CREATE_INDEX = $AD;
  LOP_DROP_INDEX = $AE;
  LOP_CREATE_ALLOCCHAIN = $B0;
  LOP_CREATE_FTCAT = $B4;
  LOP_DROP_FTCAT = $B5;
  LOP_REPL_COMMAND = $C8;
  LOP_BEGIN_UPDATE = $C9;
  LOP_END_UPDATE = $CA;
  LOP_TEXT_POINTER = $CB;
  LOP_TEXT_INFO_BEGIN = $CC;
  LOP_TEXT_INFO_END = $CD;
  LOP_REPL_NOOP = $CE;
  LOP_TEXT_VALUE = $CF;
  LOP_SHRINK_NOOP = $D3;
  LOP_FILESTREAM_INFO_BEGIN = $D4;
  LOP_FILESTREAM_INFO_END = $D5;
  LOP_BULK_EXT_ALLOCATION = $D6;
  LOP_SECURITY_OP = $D7;
  LOP_PAGE_REENCRYPT = $D8;
  LOP_CREATE_PHYSICAL_FILE = $D9;
  LOP_RANGE_INSERT = $DC;
  LOP_INVALIDATE_CACHE = $DD;
  LOP_CSI_ROWGROUP = $DF;
  LOP_HK = $E6;
  LOP_HK_CHECKPOINT = $E7;
  LOP_HK_CHAINED = $E8;
  LOP_SEREPL_MSG = $F0;

  function OpcodeToStr(val: Integer): string;

implementation

function OpcodeToStr(val: Integer): string;
begin
  case val of
    LOP_NULL:
      result := 'LOP_NULL';
    LOP_FORMAT_PAGE:
      result := 'LOP_FORMAT_PAGE';
    LOP_INSERT_ROWS:
      result := 'LOP_INSERT_ROWS';
    LOP_DELETE_ROWS:
      result := 'LOP_DELETE_ROWS';
    LOP_MODIFY_ROW:
      result := 'LOP_MODIFY_ROW';
    LOP_MODIFY_HEADER:
      result := 'LOP_MODIFY_HEADER';
    LOP_MODIFY_COLUMNS:
      result := 'LOP_MODIFY_COLUMNS';
    LOP_SET_BITS:
      result := 'LOP_SET_BITS';
    LOP_SET_FREE_SPACE:
      result := 'LOP_SET_FREE_SPACE';
    LOP_DELETE_SPLIT:
      result := 'LOP_DELETE_SPLIT';
    LOP_UNDO_DELETE_SPLIT:
      result := 'LOP_UNDO_DELETE_SPLIT';
    LOP_EXPUNGE_ROWS:
      result := 'LOP_EXPUNGE_ROWS';
    LOP_FILE_HDR_MODIFY:
      result := 'LOP_FILE_HDR_MODIFY';
    LOP_CLEAR_GAM_BITS:
      result := 'LOP_CLEAR_GAM_BITS';
    LOP_COUNT_DELTA:
      result := 'LOP_COUNT_DELTA';
    LOP_ROOT_CHANGE:
      result := 'LOP_ROOT_CHANGE';
    LOP_COMPRESSION_INFO:
      result := 'LOP_COMPRESSION_INFO';
    LOP_ENCRYPT_PAGE:
      result := 'LOP_ENCRYPT_PAGE';
    LOP_INSYSXACT:
      result := 'LOP_INSYSXACT';
    LOP_REMOVE_VERSION_INFO:
      result := 'LOP_REMOVE_VERSION_INFO';
    LOP_BEGIN_XACT:
      result := 'LOP_BEGIN_XACT';
    LOP_COMMIT_XACT:
      result := 'LOP_COMMIT_XACT';
    LOP_ABORT_XACT:
      result := 'LOP_ABORT_XACT';
    LOP_PREP_XACT:
      result := 'LOP_PREP_XACT';
    LOP_MARK_SAVEPOINT:
      result := 'LOP_MARK_SAVEPOINT';
    LOP_FORGET_XACT:
      result := 'LOP_FORGET_XACT';
    LOP_CREATE_FILE:
      result := 'LOP_CREATE_FILE';
    LOP_DROP_FILE:
      result := 'LOP_DROP_FILE';
    LOP_HOBT_DDL:
      result := 'LOP_HOBT_DDL';
    LOP_IDENT_NEWVAL:
      result := 'LOP_IDENT_NEWVAL';
    LOP_IDENT_SENTVAL:
      result := 'LOP_IDENT_SENTVAL';
    LOP_HOBT_DELTA:
      result := 'LOP_HOBT_DELTA';
    LOP_LOCK_XACT:
      result := 'LOP_LOCK_XACT';
    LOP_CREATE_STREAMFILE:
      result := 'LOP_CREATE_STREAMFILE';
    LOP_MIGRATE_LOCKS:
      result := 'LOP_MIGRATE_LOCKS';
    LOP_DROP_STREAMFILE:
      result := 'LOP_DROP_STREAMFILE';
    LOP_FS_DOWNLEVEL_OP:
      result := 'LOP_FS_DOWNLEVEL_OP';
    LOP_MODIFY_STREAMFILE_HDR:
      result := 'LOP_MODIFY_STREAMFILE_HDR';
    LOP_BP_DBVER:
      result := 'LOP_BP_DBVER';
    LOP_COPY_VERSION_INFO:
      result := 'LOP_COPY_VERSION_INFO';
    LOP_BEGIN_CKPT:
      result := 'LOP_BEGIN_CKPT';
    LOP_XACT_CKPT:
      result := 'LOP_XACT_CKPT';
    LOP_END_CKPT:
      result := 'LOP_END_CKPT';
    LOP_BUF_WRITE:
      result := 'LOP_BUF_WRITE';
    LOP_BEGIN_RECOVERY:
      result := 'LOP_BEGIN_RECOVERY';
    LOP_END_RECOVERY:
      result := 'LOP_END_RECOVERY';
    LOP_TENANT_LOG:
      result := 'LOP_TENANT_LOG';
    LOP_FEDTM_INFO:
      result := 'LOP_FEDTM_INFO';
    LOP_CREATE_INDEX:
      result := 'LOP_CREATE_INDEX';
    LOP_DROP_INDEX:
      result := 'LOP_DROP_INDEX';
    LOP_CREATE_ALLOCCHAIN:
      result := 'LOP_CREATE_ALLOCCHAIN';
    LOP_CREATE_FTCAT:
      result := 'LOP_CREATE_FTCAT';
    LOP_DROP_FTCAT:
      result := 'LOP_DROP_FTCAT';
    LOP_REPL_COMMAND:
      result := 'LOP_REPL_COMMAND';
    LOP_BEGIN_UPDATE:
      result := 'LOP_BEGIN_UPDATE';
    LOP_END_UPDATE:
      result := 'LOP_END_UPDATE';
    LOP_TEXT_POINTER:
      result := 'LOP_TEXT_POINTER';
    LOP_TEXT_INFO_BEGIN:
      result := 'LOP_TEXT_INFO_BEGIN';
    LOP_TEXT_INFO_END:
      result := 'LOP_TEXT_INFO_END';
    LOP_REPL_NOOP:
      result := 'LOP_REPL_NOOP';
    LOP_TEXT_VALUE:
      result := 'LOP_TEXT_VALUE';
    LOP_SHRINK_NOOP:
      result := 'LOP_SHRINK_NOOP';
    LOP_FILESTREAM_INFO_BEGIN:
      result := 'LOP_FILESTREAM_INFO_BEGIN';
    LOP_FILESTREAM_INFO_END:
      result := 'LOP_FILESTREAM_INFO_END';
    LOP_BULK_EXT_ALLOCATION:
      result := 'LOP_BULK_EXT_ALLOCATION';
    LOP_SECURITY_OP:
      result := 'LOP_SECURITY_OP';
    LOP_PAGE_REENCRYPT:
      result := 'LOP_PAGE_REENCRYPT';
    LOP_CREATE_PHYSICAL_FILE:
      result := 'LOP_CREATE_PHYSICAL_FILE';
    LOP_RANGE_INSERT:
      result := 'LOP_RANGE_INSERT';
    LOP_INVALIDATE_CACHE:
      result := 'LOP_INVALIDATE_CACHE';
    LOP_CSI_ROWGROUP:
      result := 'LOP_CSI_ROWGROUP';
    LOP_HK:
      result := 'LOP_HK';
    LOP_HK_CHECKPOINT:
      result := 'LOP_HK_CHECKPOINT';
    LOP_HK_CHAINED:
      result := 'LOP_HK_CHAINED';
    LOP_SEREPL_MSG:
      result := 'LOP_SEREPL_MSG';
  end;
end;

end.

