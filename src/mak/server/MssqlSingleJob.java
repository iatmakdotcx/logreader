package mak.server;

import org.apache.log4j.PropertyConfigurator;

import mak.triPart.zk;

public class MssqlSingleJob {
	public zk zkClient = new zk(); 
	private String jobkey = "";
	private String LSN = "";
	
	public static void main(String[] args) {
		PropertyConfigurator.configure("config/log4j.properties");
		String jobkey = "";
		String LSN = "";
		MssqlSingleJob job = new MssqlSingleJob(jobkey,LSN);
		job.run();
		
	}
	MssqlSingleJob(String jobkey, String LSN){
		this.jobkey = jobkey;
		this.LSN = LSN;		
	}
	
	void run(){
		zkClient.initCfg(jobkey);
		String getdbConStr = zkClient.getdbConStr();
		
	}
}
