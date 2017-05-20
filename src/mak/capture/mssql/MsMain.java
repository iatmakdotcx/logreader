package mak.capture.mssql;


import mak.capture.log.ConsoleOutput;
import mak.tools.HexTool;

public class MsMain {
	private MsDict md;
	
	public MsMain(){
		MsDatabase _Db = new MsDatabase(ConsoleOutput.getInstance(), "192.168.0.61","sa","xxk@20130220","MaktestDB");
		
		md = new MsDict(_Db);
		if (md.CheckDBState()){
			md.RefreshDBDict();
		}
		
	}
	
	public void testDelete() {
		MsLogDelete mmL = new MsLogDelete();
		mmL.md = md;
		mmL.table = md.list_MsTable.get(117575457);
		mmL.LSN = "00000017:000000fa:0002";
		mmL.r0 = HexTool.getByteArrayFromHexString("30003A0042443841344242452D303731352D343730302D393537382D3742414439454430324138337F969800616161616120202020202800000005000001005900616161616161616161616161616161616161616161616161");

		System.out.println(mmL.BuildSql());
	}
	
	public void testInsert() {
		MsLogInsert mmL = new MsLogInsert();
		mmL.md = md;
		mmL.table = md.list_MsTable.get(1333579789);
		mmL.LSN = "00000017:000000fa:0002";
		mmL.r0 = HexTool.getByteArrayFromHexString("300047000100000030303230303032303030373501000000000000000041000000003234D6D0CEC428BCF2CCE529202D20BCABC6B7CEE5B1CA372E31B0E6202020203038FFFFFF1A000000D00005005D006300630076008680CCB7C0F230303230544C3439343835303439353135352C3232323232320000FF0B00000000DB00000001000100");

		System.out.println(mmL.BuildSql());
	}
	
	public void testUpdate_LOP_MODIFY_ROW() {
		MsLogUpdate mmL = new MsLogUpdate();
		mmL.table = md.list_MsTable.get(117575457);
		mmL.operation = "LOP_MODIFY_ROW";
		mmL.r0 = HexTool.getByteArrayFromHexString("6161616161");
		mmL.r1 = HexTool.getByteArrayFromHexString("6262626262");
		mmL.r2 = HexTool.getByteArrayFromHexString("1636433837444631332D454630362D343737332D423732372D444238434233423231443535010000");
		mmL.offset = 65;
		mmL.LSN = "00000017:000000fa:0002";
		mmL.md = md;
		
		System.out.println(mmL.BuildSql());
	}
	
	
	public void testUpdate() {
		MsLogUpdate mmL = new MsLogUpdate();
		mmL.table = md.list_MsTable.get(117575457);
		mmL.LogRecord = HexTool.getByteArrayFromHexString("00003E0018000000FC00000001000200D90300000000060277000000010000002300000018000000FB00000002000001000013000000000100000000000008000800040028001A0001000100070007004800480065006500010007001636433837444631332D454630362D343737332D423732372D4442384342334232314435350100000101000C0000210F02070000010200040204000A33FD75D9FF1500006601000C6500210F66313131313131003131313131316631");
		mmL.LSN = "00000017:000000fa:0002";
		mmL.md = md;
		
		System.out.println(mmL.BuildSql());
	}

}
