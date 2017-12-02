unit MsOdsApi;

//------------------------------------------------------------
// Open Data Services header file: srv.h
// Copyright (c) 1989, 1990, 1991, 1997 by Microsoft Corp.
//

// Avoid double inclusion
//#ifndef _ODS_SRV_H_
//  _ODS_SRV_H_

//#include "windows.h"

// ODS uses pack(4) on all CPU types
//#pragma pack(4)

//#ifdef __cplusplus
//extern "C" {
//#endif

// define model
//#if !defined( FAR )
//  FAR far
//#endif

//------------------------------------------------------------
// Formats of data types
//#if !defined(DBTYPEDEFS) // Do not conflict with DBLIB definitions
//#if !defined(MAXNUMERICLEN) // Do not conflict with ODBC definitions

//  DBTYPEDEFS

interface

uses
  Windows;

type
  DBBOOL = Byte;

  DBBYTE = Byte;

  DBTINYINT = Byte;

  DBSMALLINT = Smallint;

  DBUSMALLINT = Word;

  DBINT = Longint;

  DBCHAR = Char;

  PDBCHAR = ^DBCHAR;

  DBBINARY = Byte;

  DBBIT = Byte;

  DBFLT8 = Double;

  srv_datetime = record
   // Format for SRVDATETIME
    dtdays: Longint;  // number of days since 1/1/1900
    dttime: Longword; // number 300th second since mid
  end;

  DBDATETIME = srv_datetime;

  srv_dbdatetime4 = record
   // Format for SRVDATETIM4
    numdays: Word; // number of days since 1/1/1900
    nummins: Word; // number of minutes sicne midnight
  end;

  DBDATETIM4 = srv_dbdatetime4;

  srv_money = record
   // Format for SRVMONEY
    mnyhigh: Longint;
    mnylow: Longword;
  end;

  DBMONEY = srv_money;

  DBFLT4 = Double;

  DBMONEY4 = Longint;

const
  MAXNUMERICDIG = 38;
  DEFAULTPRECISION = 19; // 18
  DEFAULTSCALE = 0;
  MAXNUMERICLEN = 16;

type
  srv_dbnumeric = packed record
   // Format for SRVNUMERIC,SRVNUMERICN,SRVDECIMAL,SRVDECIMALN
    precision: Byte;
    scale: Byte;
    sign: Byte;                               // 1 = Positive, 0 = Negative
    val: array[0..MAXNUMERICLEN - 1] of Byte; // Padded little-endian value
  end;

  DBNUMERIC = srv_dbnumeric;

  DBDECIMAL = DBNUMERIC;

//#endif  // #if !defined(MAXNUMERICLEN)
//#endif  // #if !defined( DBTYPEDEFS )

//------------------------------------------------------------
// Constants used by APIs

// Type Tokens
const
  SRV_TDS_NULL = $1f;
  SRV_TDS_TEXT = $23;
  SRV_TDS_GUID = $24;
  SRV_TDS_VARBINARY = $25;
  SRV_TDS_INTN = $26;
  SRV_TDS_VARCHAR = $27;
  SRV_TDS_BINARY = $2d;
  SRV_TDS_IMAGE = $22;
  SRV_TDS_CHAR = $2f;
  SRV_TDS_INT1 = $30;
  SRV_TDS_BIT = $32;
  SRV_TDS_INT2 = $34;
  SRV_TDS_DECIMAL = $37;
  SRV_TDS_INT4 = $38;
  SRV_TDS_DATETIM4 = $3a;
  SRV_TDS_FLT4 = $3b;
  SRV_TDS_MONEY = $3c;
  SRV_TDS_DATETIME = $3d;
  SRV_TDS_FLT8 = $3e;
  SRV_TDS_NUMERIC = $3f;
  SRV_TDS_NTEXT = $63;
  SRV_TDS_BITN = $68;
  SRV_TDS_DECIMALN = $6a;
  SRV_TDS_NUMERICN = $6c;
  SRV_TDS_FLTN = $6d;
  SRV_TDS_MONEYN = $6e;
  SRV_TDS_DATETIMN = $6f;
  SRV_TDS_MONEY4 = $7a;
  SRV_TDS_INT8 = $7f;  // SQL 2000 and later
  SRV_TDS_BIGVARBINARY = $A5;
  SRV_TDS_BIGVARCHAR = $A7;
  SRV_TDS_BIGBINARY = $AD;
  SRV_TDS_BIGCHAR = $AF;
  SRV_TDS_NVARCHAR = $e7;
  SRV_TDS_NCHAR = $ef;

// Datatypes
// Also: values of symbol parameter to srv_symbol when type = SRV_DATATYPE
  SRVNULL = SRV_TDS_NULL;
  SRVTEXT = SRV_TDS_TEXT;
  SRVGUID = SRV_TDS_GUID;
  SRVVARBINARY = SRV_TDS_VARBINARY;
  SRVINTN = SRV_TDS_INTN;
  SRVVARCHAR = SRV_TDS_VARCHAR;
  SRVBINARY = SRV_TDS_BINARY;
  SRVIMAGE = SRV_TDS_IMAGE;
  SRVCHAR = SRV_TDS_CHAR;
  SRVINT1 = SRV_TDS_INT1;
  SRVBIT = SRV_TDS_BIT;
  SRVINT2 = SRV_TDS_INT2;
  SRVDECIMAL = SRV_TDS_DECIMAL;
  SRVINT4 = SRV_TDS_INT4;
  SRVDATETIM4 = SRV_TDS_DATETIM4;
  SRVFLT4 = SRV_TDS_FLT4;
  SRVMONEY = SRV_TDS_MONEY;
  SRVDATETIME = SRV_TDS_DATETIME;
  SRVFLT8 = SRV_TDS_FLT8;
  SRVNUMERIC = SRV_TDS_NUMERIC;
  SRVNTEXT = SRV_TDS_NTEXT;
  SRVBITN = SRV_TDS_BITN;
  SRVDECIMALN = SRV_TDS_DECIMALN;
  SRVNUMERICN = SRV_TDS_NUMERICN;
  SRVFLTN = SRV_TDS_FLTN;
  SRVMONEYN = SRV_TDS_MONEYN;
  SRVDATETIMN = SRV_TDS_DATETIMN;
  SRVMONEY4 = SRV_TDS_MONEY4;
  SRVINT8 = SRV_TDS_INT8;        // SQL 2000 and later
  SRVBIGVARBINARY = SRV_TDS_BIGVARBINARY;
  SRVBIGVARCHAR = SRV_TDS_BIGVARCHAR;
  SRVBIGBINARY = SRV_TDS_BIGBINARY;
  SRVBIGCHAR = SRV_TDS_BIGCHAR;
  SRVNVARCHAR = SRV_TDS_NVARCHAR;
  SRVNCHAR = SRV_TDS_NCHAR;

// values for srv_symbol type parameter
  SRV_ERROR = 0;
  SRV_DONE = 1;
  SRV_DATATYPE = 2;
  SRV_EVENT = 4;

// values for srv_symbol symbol parameter, when type = SRV_ERROR
  SRV_ENO_OS_ERR = 0;
  SRV_INFO = 1;
  SRV_FATAL_PROCESS = 10;
  SRV_FATAL_SERVER = 19;

// Types of server events
// Also: values for srv_symbol symbol parameter, when type = SRV_EVENT
  SRV_CONTINUE = 0;
  SRV_LANGUAGE = 1;
  SRV_CONNECT = 2;
  SRV_RPC = 3;
  SRV_RESTART = 4;
  SRV_DISCONNECT = 5;
  SRV_ATTENTION = 6;
  SRV_SLEEP = 7;
  SRV_START = 8;
  SRV_STOP = 9;
  SRV_EXIT = 10;
  SRV_CANCEL = 11;
  SRV_SETUP = 12;
  SRV_CLOSE = 13;
  SRV_PRACK = 14;
  SRV_PRERROR = 15;
  SRV_ATTENTION_ACK = 16;
  SRV_CONNECT_V7 = 16; // TDS type for TDS 7 clients.  Overloaded with SRV_ATTENTION_ACK
  SRV_SKIP = 17;
  SRV_TRANSMGR = 18;
  SRV_OLEDB = 20;
  SRV_INTERNAL_HANDLER = 99;
  SRV_PROGRAMMER_DEFINED = 100;

// values for srv_config option parameter
  SRV_CONNECTIONS = 1;
  SRV_LOGFILE = 2;
  SRV_STACKSIZE = 3;
  SRV_REMOTE_ACCESS = 7;
  SRV_REMOTE_CONNECTIONS = 9;
  SRV_MAX_PACKETS = 10;
  SRV_MAXWORKINGTHREADS = 11;
  SRV_MINWORKINGTHREADS = 12;
  SRV_THREADTIMEOUT = 13;
  SRV_MAX_PACKETSIZE = 17;
  SRV_THREADPRIORITY = 18;
  SRV_ANSI_CODEPAGE = 19;
  SRV_DEFAULT_PACKETSIZE = 26;
  SRV_PASSTHROUGH = 27;

// vlaues for srv_config value parameter when option = SRV_THREADPRIORITY
  SRV_PRIORITY_LOW = THREAD_PRIORITY_LOWEST;
  SRV_PRIORITY_NORMAL = THREAD_PRIORITY_NORMAL;
  SRV_PRIORITY_HIGH = THREAD_PRIORITY_HIGHEST;
  SRV_PRIORITY_CRITICAL = THREAD_PRIORITY_TIME_CRITICAL;

// values for srv_sfield field parameter
  SRV_SERVERNAME = 0;
  SRV_VERSION = 6;

// Length to indicate string is null terminated
  SRV_NULLTERM = -1;

// values of msgtype parameter to srv_sendmsg
  SRV_MSG_INFO = 1;
  SRV_MSG_ERROR = 2;

// values of status parameter to srv_senddone
// Also: values for symbol parameters to srv_symbol when type = SRV_DONE
  SRV_DONE_FINAL = $0000;
  SRV_DONE_MORE = $0001;
  SRV_DONE_ERROR = $0002;
  SRV_DONE_COUNT = $0010;
  SRV_DONE_RPC_IN_BATCH = $0080;

// return values of srv_paramstatus
  SRV_PARAMRETURN = $0001;
  SRV_PARAMDEFAULT = $0002;

// return values of srv_rpcoptions
  SRV_RECOMPILE = $0001;
  SRV_NOMETADATA = $0002;

// values of field parameter to srv_pfield
//  SRV_LANGUAGE 1   already defined above
//  SRV_EVENT    4   already defined above
  SRV_SPID = 10;
  SRV_NETSPID = 11;
  SRV_TYPE = 12;
  SRV_STATUS = 13;
  SRV_RMTSERVER = 14;
  SRV_HOST = 15;
  SRV_USER = 16;
  SRV_PWD = 17;
  SRV_CPID = 18;
  SRV_APPLNAME = 19;
  SRV_TDS = 20;
  SRV_CLIB = 21;
  SRV_LIBVERS = 22;
  SRV_ROWSENT = 23;
  SRV_BCPFLAG = 24;
  SRV_NATLANG = 25;
  SRV_PIPEHANDLE = 26;
  SRV_NETWORK_MODULE = 27;
  SRV_NETWORK_VERSION = 28;
  SRV_NETWORK_CONNECTION = 29;
  SRV_LSECURE = 30;
  SRV_SAXP = 31;
  SRV_UNICODE_USER = 33;
  SRV_UNICODE_PWD = 35;
  SRV_SPROC_CODEPAGE = 36;

// return value of SRV_TDSVERSION macro
  SRV_TDS_NONE = 0;
  SRV_TDS_2_0 = 1;
  SRV_TDS_3_4 = 2;
  SRV_TDS_4_2 = 3;
  SRV_TDS_6_0 = 4;
  SRV_TDS_7_0 = 5;

// Return values from APIs
type
  SRVRETCODE = Integer;        // SUCCEED or FAIL

  RETCODE = Integer;

const
  SUCCEED = 1;   // Successful return value
  FAIL = 0;   // Unsuccessful return value

  SRV_DUPLICATE_HANDLER = 2;   // additional return value for srv_pre/post_handle

//------------------------------------------------
//PreDeclare structures
//
{struct srv_server;
typedef struct srv_server SRV_SERVER;

struct srv_config;
typedef struct srv_config SRV_CONFIG;

struct srv_proc;
typedef struct srv_proc SRV_PROC;}

type
  SRV_SERVER = Pointer;

  SRV_CONFIG = Pointer;

  SRV_PROC = Pointer;

//------------------------------------------------
//------------------------------------------------
// ODS MACROs & APIs

// Describing and sending a result set
function srv_describe(srvproc: SRV_PROC; colnumber: Integer; column_name: PAnsiChar; namelen: Integer; desttype, destlen, srctype, srclen: Integer; srcData: Pointer): Integer; cdecl;

function srv_setutype(srvproc: SRV_PROC; column: Integer; usertype: Longint): Integer; cdecl;

function srv_setcoldata(srvproc: SRV_PROC; column: Integer; data: Pointer): Integer; cdecl;

function srv_setcollen(srvproc: SRV_PROC; column, len: Integer): Integer; cdecl;

function srv_sendrow(srvproc: SRV_PROC): Integer; cdecl;

function srv_senddone(srvproc: SRV_PROC; status, curcmd: Word; count: Longint): Integer; cdecl;

// Dealing with Extended Procedure parameters
function srv_rpcparams(srvproc: SRV_PROC): Integer; cdecl;

function srv_paraminfo(srvproc: SRV_PROC; n: Integer; pbType: PByte; pcbMaxLen, pcbActualLen: PULONG; pbData: PByte; pfNull: PBOOL): Integer; cdecl;

function srv_paramsetoutput(srvproc: SRV_PROC; n: Integer; pbData: PByte; cbLen: ULONG; fNull: BOOL): Integer; cdecl;

function srv_paramdata(srvproc: SRV_PROC; n: Integer): Pointer; cdecl;

function srv_paramlen(srvproc: SRV_PROC; n: Integer): Integer; cdecl;

function srv_parammaxlen(srvproc: SRV_PROC; n: Integer): Integer; cdecl;

function srv_paramtype(srvproc: SRV_PROC; n: Integer): Integer; cdecl;

function srv_paramset(srvproc: SRV_PROC; n: Integer; data: Pointer; int: Integer): Integer; cdecl;

function srv_paramname(srvproc: SRV_PROC; n: Integer; var len: Integer): PAnsiChar; cdecl;

function srv_paramnumber(srvproc: SRV_PROC; name: PAnsiChar; namelen: Integer): Integer; cdecl;

//--------------------------------------------------------------
//--------------------------------------------------------------
// The rest of these APIs are still supported, in SQL Server 7.0,
// but may not be supported after SQL Server 7.0

// MACROs
{  SRV_GETCONFIG(a)      srv_getconfig     ( a )
 SRV_GETSERVER(a)      srv_getserver     ( a )
 SRV_GOT_ATTENTION(a)   srv_got_attention ( a )
SRV_EVENTDATA(a)      srv_eventdata     ( a )
SRV_IODEAD(a)         srv_iodead        ( a )
SRV_TDSVERSION(a)      srv_tdsversion     ( a )}

function srv_getconfig(server: SRV_SERVER): SRV_CONFIG; cdecl;

function srv_getserver(srvproc: SRV_PROC): SRV_SERVER; cdecl;

function srv_got_attention(srvproc: SRV_PROC): Bool; cdecl;

function srv_eventdata(srvproc: SRV_PROC): Pointer; cdecl;

// Memory
function srv_alloc(ulSize: Longint): Pointer; cdecl;

function srv_bmove(from: Pointer; pto: Pointer; count: Longint): Integer; cdecl;

function srv_bzero(location: Pointer; count: Longint): Integer; cdecl;

function srv_free(ptr: Pointer): Integer; cdecl;

function srv_config_fn(config: SRV_CONFIG; option: Longint; value: PAnsiChar; valuelen: Integer): Integer; cdecl;

function srv_config_alloc: SRV_CONFIG; cdecl;

function srv_convert(srvproc: SRV_PROC; srctype: Integer; src: Pointer; srclen: DBINT; desttype: Integer; dest: Pointer; destlen: DBINT): Integer; cdecl;
{
int (*  srv_errhandle(int (* handler)(SRV_SERVER * server,
    SRV_PROC   * srvproc,
    int         srverror,
    BYTE           severity,
    BYTE           state,
    int         oserrnum,
    char     * errtext,
    int         errtextlen,
    char     * oserrtext,
    int         oserrtextlen)))
  ( SRV_SERVER * server,
   SRV_PROC   * srvproc,
   int        srverror,
   BYTE          severity,
   BYTE          state,
   int        oserrnum,
   char     * errtext,
   int        errtextlen,
   char     * oserrtext,
   int        oserrtextlen );
}

function srv_event_fn(srvproc: SRV_PROC; event: Integer; data: PByte): Integer; cdecl;

function srv_getuserdata(srvproc: SRV_PROC): Pointer; cdecl;

function srv_getbindtoken(srvproc: SRV_PROC; token_buf: PAnsiChar): Integer; cdecl;

function srv_getdtcxact(srvproc: SRV_PROC; ppv: Pointer): Integer; cdecl;

//typedef int (* EventHandler)(void*);
type
  EventHandler = Pointer;

function srv_handle(server: SRV_SERVER; int: Longint; handler: EventHandler): EventHandler; cdecl;

function srv_impersonate_client(srvproc: SRV_PROC): Integer; cdecl;

function srv_init(config: SRV_CONFIG; connectname: PAnsiChar; namelen: Integer): SRV_SERVER; cdecl;

function srv_iodead(srvproc: SRV_PROC): Bool; cdecl;

function srv_langcpy(srvproc: SRV_PROC; start, nbytes: Longint; buffer: PAnsiChar): Longint; cdecl;

function srv_langlen(srvproc: SRV_PROC): Longint; cdecl;

function srv_langptr(srvproc: SRV_PROC): Pointer; cdecl;

function srv_log(server: SRV_SERVER; datestamp: Bool; msg: PAnsiChar; msglen: Integer): Integer; cdecl;

function srv_paramstatus(srvproc: SRV_PROC; n: Integer): Integer; cdecl;

function srv_pfield(srvproc: SRV_PROC; field: Integer; len: PInteger): PAnsiChar; cdecl;

function srv_returnval(srvproc: SRV_PROC; value_name: PDBCHAR; len: Integer; status: Byte; iType, maxlen, datalen: DBINT; value: PByte): Integer; cdecl;

function srv_revert_to_self(srvproc: SRV_PROC): Integer; cdecl;

function srv_rpcdb(srvproc: SRV_PROC; len: PInteger): PAnsiChar; cdecl;

function srv_rpcname(srvproc: SRV_PROC; len: PInteger): PAnsiChar; cdecl;

function srv_rpcnumber(srvproc: SRV_PROC): Integer; cdecl;

function srv_rpcoptions(srvproc: SRV_PROC): Word; cdecl;

function srv_rpcowner(srvproc: SRV_PROC; len: PInteger): PAnsiChar; cdecl;

function srv_run(server: SRV_SERVER): Integer; cdecl;

function srv_sendmsg(srvproc: SRV_PROC; msgtype: Integer; msgnum: DBINT; msgClass, state: DBTINYINT; rpcname: PAnsiChar; rpcnamelen: Integer; linenum: Word; msg: PAnsiChar; msglen: Integer): Integer; cdecl;

function srv_ansi_sendmsg(srvproc: SRV_PROC; msgtype: Integer; msgnum: DBINT; msgClass, state: DBTINYINT; rpcname: PAnsiChar; rpcnamelen: Integer; linenum: Word; msg: PAnsiChar; msglen: Integer): Integer; cdecl;

function srv_sendstatus(srvproc: SRV_PROC; status: Longint): Integer; cdecl;

function srv_setuserdata(srvproc: SRV_PROC; ptr: Pointer): Integer; cdecl;

function srv_sfield(server: SRV_SERVER; field: Integer; len: PInteger): PAnsiChar; cdecl;

function srv_symbol(iType, symbol: Integer; len: PInteger): PAnsiChar; cdecl;

function srv_tdsversion(srvproc: SRV_PROC): Integer; cdecl;

function srv_writebuf(srvproc: SRV_PROC; ptr: Pointer; count: Word): Integer; cdecl;

function srv_willconvert(srctype, desttype: Integer): Bool; cdecl;

procedure srv_ackattention(srvproc: SRV_PROC); cdecl;

function srv_terminatethread(srvproc: SRV_PROC): Integer; cdecl;

function srv_sendstatistics(srvproc: SRV_PROC): Integer; cdecl;

function srv_clearstatistics(srvproc: SRV_PROC): Integer; cdecl;

function srv_setevent(server: SRV_SERVER; event: Integer): Integer; cdecl;

function srv_message_handler(srvproc: SRV_PROC; errornum: Integer; severity, state: Byte; oserrnum: Integer; errtext: PAnsiChar; errtextlen: Integer; oserrtext: PAnsiChar; oserrtextlen: Integer): Integer; cdecl;

function srv_pre_handle(server: SRV_SERVER; srvproc: SRV_PROC; event: Longint; handler: EventHandler; remove: Bool): Integer; cdecl;

function srv_post_handle(server: SRV_SERVER; srvproc: SRV_PROC; event: Longint; handler: EventHandler; remove: Bool): Integer; cdecl;

function srv_post_completion_queue(srvproc: SRV_PROC; inbuf: PAnsiChar; inbuflen: PAnsiChar): Integer; cdecl;

function srv_IgnoreAnsiToOem(srvproc: SRV_PROC; bTF: BOOL): Integer; cdecl;

//#ifdef __cplusplus
//}
//#endif

//#pragma pack()

const
  SS_MAJOR_VERSION = 7;
  SS_MINOR_VERSION = 00;
  SS_LEVEL_VERSION = 0000;
  SS_MINIMUM_VERSION = '7.00.00.0000';
  ODS_VERSION = ((SS_MAJOR_VERSION shl 24) or (SS_MINOR_VERSION shl 16));

//#endif //_ODS_SRV_H_

//////////////////////////////////////////////////////////////////
// Suggested implementation of __GetXpVersion
//
//__declspec(dllexport) ULONG __GetXpVersion()
//   {
//   return ODS_VERSION;
//   }
//////////////////////////////////////////////////////////////////

implementation

const
  sLibName = 'Opends60.DLL';

function srv_describe; external sLibName name 'srv_describe';

function srv_setutype; external sLibName name 'srv_setutype';

function srv_setcoldata; external sLibName name 'srv_setcoldata';

function srv_setcollen; external sLibName name 'srv_setcollen';

function srv_sendrow; external sLibName name 'srv_sendrow';

function srv_senddone; external sLibName name 'srv_senddone';

// Dealing with Extended Procedure parameters
function srv_rpcparams; external sLibName name 'srv_rpcparams';

function srv_paraminfo; external sLibName name 'srv_paraminfo';

function srv_paramsetoutput; external sLibName name 'srv_paramsetoutput';

function srv_paramdata; external sLibName name 'srv_paramdata';

function srv_paramlen; external sLibName name 'srv_paramlen';

function srv_parammaxlen; external sLibName name 'srv_parammaxlen';

function srv_paramtype; external sLibName name 'srv_paramtype';

function srv_paramset; external sLibName name 'srv_paramset';

function srv_paramname; external sLibName name 'srv_paramname';

function srv_paramnumber; external sLibName name 'srv_paramnumber';

//--------------------------------------------------------------
// The rest of these APIs are still supported, in SQL Server 7.0,
// but may not be supported after SQL Server 7.0

function srv_getconfig; external sLibName name 'srv_getconfig';

function srv_getserver; external sLibName name 'srv_getserver';

function srv_got_attention; external sLibName name 'srv_got_attention';

function srv_eventdata; external sLibName name 'srv_eventdata';

// Memory
function srv_alloc; external sLibName name 'srv_alloc';

function srv_bmove; external sLibName name 'srv_bmove';

function srv_bzero; external sLibName name 'srv_bzero';

function srv_free; external sLibName name 'srv_free';

function srv_config_fn; external sLibName name 'srv_config';

function srv_config_alloc; external sLibName name 'srv_config_alloc';

function srv_convert; external sLibName name 'srv_convert';

function srv_event_fn; external sLibName name 'srv_event';

function srv_getuserdata; external sLibName name 'srv_getuserdata';

function srv_getbindtoken; external sLibName name 'srv_getbindtoken';

function srv_getdtcxact; external sLibName name 'srv_getdtcxact';

function srv_handle; external sLibName name 'srv_handle';

function srv_impersonate_client; external sLibName name 'srv_impersonate_client';

function srv_init; external sLibName name 'srv_init';

function srv_iodead; external sLibName name 'srv_iodead';

function srv_langcpy; external sLibName name 'srv_langcpy';

function srv_langlen; external sLibName name 'srv_langlen';

function srv_langptr; external sLibName name 'srv_langptr';

function srv_log; external sLibName name 'srv_log';

function srv_paramstatus; external sLibName name 'srv_paramstatus';

function srv_pfield; external sLibName name 'srv_pfield';

function srv_returnval; external sLibName name 'srv_returnval';

function srv_revert_to_self; external sLibName name 'srv_revert_to_self';

function srv_rpcdb; external sLibName name 'srv_rpcdb';

function srv_rpcname; external sLibName name 'srv_rpcname';

function srv_rpcnumber; external sLibName name 'srv_rpcnumber';

function srv_rpcoptions; external sLibName name 'srv_rpcoptions';

function srv_rpcowner; external sLibName name 'srv_rpcowner';

function srv_run; external sLibName name 'srv_run';

function srv_sendmsg; external sLibName name 'srv_sendmsg';

function srv_ansi_sendmsg; external sLibName name 'srv_ansi_sendmsg';

function srv_sendstatus; external sLibName name 'srv_sendstatus';

function srv_setuserdata; external sLibName name 'srv_setuserdata';

function srv_sfield; external sLibName name 'srv_sfield';

function srv_symbol; external sLibName name 'srv_symbol';

function srv_tdsversion; external sLibName name 'srv_tdsversion';

function srv_writebuf; external sLibName name 'srv_writebuf';

function srv_willconvert; external sLibName name 'srv_willconvert';

procedure srv_ackattention; external sLibName name 'srv_ackattention';

function srv_terminatethread; external sLibName name 'srv_terminatethread';

function srv_sendstatistics; external sLibName name 'srv_sendstatistics';

function srv_clearstatistics; external sLibName name 'srv_clearstatistics';

function srv_setevent; external sLibName name 'srv_setevent';

function srv_message_handler; external sLibName name 'srv_message_handler';

function srv_pre_handle; external sLibName name 'srv_pre_handle';

function srv_post_handle; external sLibName name 'srv_post_handle';

function srv_post_completion_queue; external sLibName name 'srv_post_completion_queue';

function srv_IgnoreAnsiToOem; external sLibName name 'srv_IgnoreAnsiToOem';

end.

