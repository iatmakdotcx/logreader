package mak.server;

import java.util.Scanner;

import org.apache.log4j.Level;
import org.apache.log4j.Logger;

import mak.triPart.zk;

public class JobConfig {
	private static zk zkClient;
	
	public static void main(String[] args) {
		zkClient = new zk();
		Logger.getRootLogger().setLevel(Level.OFF);
		zkClient.initCfg("");
		System.out.println("ok.....");
		Scanner input = new Scanner(System.in);
		while(true){
			System.out.print(">");
			String instr = input.nextLine();
			if (instr.equals("exit")) {
				break;
			}else if (instr.startsWith("jobs")) {
				String vals = getParamValue(instr, "write");
				if (!vals.isEmpty()) {
					zkClient.setPathValue("/mak/DBlog/jobs", vals);	
				}else{
					System.out.println(zkClient.getPathValue("/mak/DBlog/jobs"));					
				}
			}else if (instr.startsWith("config")) {
				String key = getParamValue(instr, "key");
				if (!key.isEmpty()) {
					String vals = getParamValue(instr, "write");
					if (!vals.isEmpty()) {
						zkClient.setPathValue("/mak/DBlog/config/"+key+"/CONSTR", vals);
					}else{
						System.out.println(zkClient.getPathValue("/mak/DBlog/config/"+key+"/CONSTR"));
					}
				}else{
					System.out.println("参数错误!");					
				}
			}else{
				System.out.println("......Help.....");
				System.out.println("\t jobs [--write] 获取或设置jobs的值");
				System.out.println("\t config --key [--write] 获取或设置config的值");
				System.out.println("\t exit");
			}
		}
		input.close();
	}
	
	public static String getParamValue(String paramStr,String key){
		String[] params = paramStr.split("\\s+");
		
		for (int i = 0; i < params.length; i++) {
			if (params[i].equals("--" + key)) {
				if(i + 1 < params.length){
					return params[i + 1];
				}
			}
		}
		return "";
	}

}
