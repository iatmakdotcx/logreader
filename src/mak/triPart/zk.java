package mak.triPart;

import java.io.FileReader;
import java.io.IOException;
import java.util.Properties;

import org.I0Itec.zkclient.ZkClient;
import org.apache.log4j.Logger;
import org.apache.log4j.PropertyConfigurator;

import mak.constants.AppConstants;

public class zk {
	private static Logger logger = Logger.getLogger(zk.class);    
	private String LSN_PATH = "/mak/c0/LSN";
	private String CONSTR_PATH = "/mak/c0/LSN";
	private static Properties initialProp;
	private static String CONNECT_ADDR = "";  
	private static int SESSION_TIMEOUT = 5000;  
	
	private boolean inited = false;
	    
	public boolean initCfg(String key) {
		if (CONNECT_ADDR.equals("")) {
			synchronized (CONNECT_ADDR) {
				if (CONNECT_ADDR.equals("")) {
					initialProp = new Properties();
					FileReader fr;
					try {
						fr = new FileReader(AppConstants.CONFIG_FILE);
						initialProp.load(fr);

						CONNECT_ADDR = initialProp.getProperty("zookeeper.connect");
						SESSION_TIMEOUT = Integer.parseInt(initialProp.getProperty("zookeeper.connection.timeout.ms"));
					} catch (IOException e) {
						logger.error("配置文件读取失败！", e);
						return false;
					}
				}
			}
		}
		LSN_PATH = "/mak/DBlog/picker/" + key + "/LSN";
		CONSTR_PATH = "/mak/DBlog/picker/" + key + "/CONSTR";
		inited = true;
		return true;
	}
	public String getPathValue(String path){
		if (!inited){
			return "";
		}
		String ResStr = "";		
		ZkClient zkClient = new ZkClient(CONNECT_ADDR, SESSION_TIMEOUT);
		try {
			if(zkClient.exists(path)){
				ResStr = zkClient.readData(path);
			}else{
				ResStr = "";	
			}
		} finally {
			zkClient.close();
		}
		return ResStr;
	}
	public boolean setPathValue(String path, String vals){
		if (!inited){
			return false;
		}
		ZkClient zkClient = new ZkClient(CONNECT_ADDR, SESSION_TIMEOUT);
		try {
			if(!zkClient.exists(path)){
				zkClient.createPersistent(path, true);
			}
			zkClient.writeData(path, vals);
			return true;
		} finally {
			zkClient.close();
		}
	}
	

	public String getLSN(){
		return getPathValue(LSN_PATH);
	}
	
	public boolean setLSN(String vals){
		return setPathValue(LSN_PATH, vals);
	}
	
	public String getdbConStr(){
		return getPathValue(CONSTR_PATH);
	}
	
	public boolean setdbConStr(String vals){
		return setPathValue(CONSTR_PATH, vals);
	}
	
	public void testFunc(String[] args){
		PropertyConfigurator.configure("config/log4j.properties");
		
		ZkClient zkClient = new ZkClient("127.0.0.1:2181", 5000);
		 //1.create和delete方法  
        //zkClient.createEphemeral("/temp"); //创建临时节点，会话失效后删除 
        zkClient.createPersistent("/mak/c0/LSN", true); //创建持久化节点，true表示如果父节点不存在则创建父节点 
        /*Thread.sleep(10000); 
        zkClient.delete("/temp"); //删除节点 
        zkClient.deleteRecursive("/super"); //递归删除，如果该节点下有子节点，会把子节点也删除 
        */  
  
        //2.设置path和data，并读取子节点和每个节点的内容  
        /*zkClient.createPersistent("/super", "1234"); //创建并设置节点的值 
        zkClient.createPersistent("/super/c1", "内容一"); 
        zkClient.createPersistent("/super/c2", "内容二"); 
        List<String> children = zkClient.getChildren("/super"); 
        for(String child : children) { 
            System.out.print(child + "："); 
            String childPath = "/super/" + child; 
            String data = zkClient.readData(childPath); //读取指定节点的值 
            System.out.println(data); 
        }*/  
		
        String cDataxx = zkClient.readData("/mak/c0/LSN");  
        System.out.println(cDataxx);  
        
		//3.更新和判断节点是否存在  
//        System.out.println(zkClient.exists("/super/c1")); //判断指定节点是否存在  
//        
//		zkClient.writeData("/mak/c0/LSN", "新内容"); //修改指定节点的值  
//        String cData = zkClient.readData("/mak/c0/LSN");  
//        System.out.println(cData);  
//        
//        zkClient.writeData("/mak/c0/LSN", "新内容1111111111111"); //修改指定节点的值  
//        String cDataxx = zkClient.readData("/mak/c0/LSN");  
//        System.out.println(cDataxx);  
//        
        zkClient.close();  
	}
}
