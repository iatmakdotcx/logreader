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
    private String CONSTR_PATH = "/mak/DBlog/config/key/CONSTR";
    private static Properties initialProp;
    private static String CONNECT_ADDR = "";
    private static int SESSION_TIMEOUT = 5000;
    private ZkClient zkClient = null;

    private boolean inited = false;

    public boolean initCfg(String key) {
        if (CONNECT_ADDR.equals("")) {
            synchronized (this) {
                if (CONNECT_ADDR.equals("")) {
                    initialProp = new Properties();
                    FileReader fr;
                    try {
                        fr = new FileReader(AppConstants.CONFIG_FILE);
                        initialProp.load(fr);

                        CONNECT_ADDR = initialProp.getProperty("zookeeper.connect");
                        SESSION_TIMEOUT = Integer.parseInt(initialProp.getProperty("zookeeper.connection.timeout.ms"));
                        if(SESSION_TIMEOUT == -1){
                        	SESSION_TIMEOUT = Integer.MAX_VALUE;
                        }
                        zkClient = new ZkClient(CONNECT_ADDR, SESSION_TIMEOUT);
                    } catch (IOException e) {
                        logger.error("�����ļ���ȡʧ�ܣ�", e);
                        return false;
                    }
                }
            }
        }
        LSN_PATH = "/mak/DBlog/picker/" + key + "/LSN";
        CONSTR_PATH = "/mak/DBlog/config/" + key + "/CONSTR";
        inited = true;
        return true;
    }
    public String getPathValue(String path) {
        if (!inited) {
            return "";
        }
        String ResStr;
        if (zkClient.exists(path)) {
            ResStr = zkClient.readData(path);
        } else {
            ResStr = "";
        }
        return ResStr;
    }

    public boolean setPathValue(String path, String vals) {
        if (!inited) {
            return false;
        }
        if (!zkClient.exists(path)) {
            zkClient.createPersistent(path, true);
        }
        zkClient.writeData(path, vals);
        return true;
    }
    
    public boolean deletePath(String path) {
        if (!inited) {
            return false;
        }
        if (zkClient.exists(path)) {
            zkClient.deleteRecursive(path);
        }
        return true;
    }
 
    public String getLSN() {
        return getPathValue(LSN_PATH);
    }

    public boolean setLSN(String vals) {
        return setPathValue(LSN_PATH, vals);
    }

    /**
     * get configure String
     *
     * @return
     */
    public String getConStr() {
        return getPathValue(CONSTR_PATH);
    }
    
    public String getConStr(String jobKey) {
    	String ConstrPath = "/mak/DBlog/config/" + jobKey + "/CONSTR";
        return getPathValue(ConstrPath);
    }

    /**
     * set configure String
     *
     * @return success
     */
    public boolean setConStr(String vals) {
        return setPathValue(CONSTR_PATH, vals);
    }

    public void testFunc(String[] args) {
        PropertyConfigurator.configure("config/log4j.properties");

        ZkClient zkClient = new ZkClient("127.0.0.1:2181", 5000);
        //1.create��delete����  
        //zkClient.createEphemeral("/temp"); //������ʱ�ڵ㣬�ỰʧЧ��ɾ�� 
        zkClient.createPersistent("/mak/c0/LSN", true); //�����־û��ڵ㣬true��ʾ������ڵ㲻�����򴴽����ڵ� 
        /*Thread.sleep(10000); 
        zkClient.delete("/temp"); //ɾ���ڵ� 
        zkClient.deleteRecursive("/super"); //�ݹ�ɾ��������ýڵ������ӽڵ㣬����ӽڵ�Ҳɾ�� 
         */

        //2.����path��data������ȡ�ӽڵ��ÿ���ڵ������  
        /*zkClient.createPersistent("/super", "1234"); //���������ýڵ��ֵ 
        zkClient.createPersistent("/super/c1", "����һ"); 
        zkClient.createPersistent("/super/c2", "���ݶ�"); 
        List<String> children = zkClient.getChildren("/super"); 
        for(String child : children) { 
            System.out.print(child + "��"); 
            String childPath = "/super/" + child; 
            String data = zkClient.readData(childPath); //��ȡָ���ڵ��ֵ 
            System.out.println(data); 
        }*/
        String cDataxx = zkClient.readData("/mak/c0/LSN");
        System.out.println(cDataxx);

        //3.���º��жϽڵ��Ƿ����  
//        System.out.println(zkClient.exists("/super/c1")); //�ж�ָ���ڵ��Ƿ����  
//        
//		zkClient.writeData("/mak/c0/LSN", "������"); //�޸�ָ���ڵ��ֵ  
//        String cData = zkClient.readData("/mak/c0/LSN");  
//        System.out.println(cData);  
//        
//        zkClient.writeData("/mak/c0/LSN", "������1111111111111"); //�޸�ָ���ڵ��ֵ  
//        String cDataxx = zkClient.readData("/mak/c0/LSN");  
//        System.out.println(cDataxx);  
//        
        zkClient.close();
    }
}
