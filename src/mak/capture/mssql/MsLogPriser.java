package mak.capture.mssql;

import java.util.Arrays;
import java.util.Properties;

import org.apache.kafka.clients.consumer.ConsumerConfig;
import org.apache.kafka.clients.consumer.ConsumerRecord;
import org.apache.kafka.clients.consumer.ConsumerRecords;
import org.apache.kafka.clients.consumer.KafkaConsumer;
import org.apache.log4j.Logger;

import mak.capture.log.OutPutMgr;
import mak.tools.StringUtil;
import mak.triPart.KafkaConfig;
import mak.triPart.zk;

public class MsLogPriser implements Runnable {
	private static Logger logger = Logger.getLogger(MsLogPriser.class);  
	private String ConnStr;
	private MsDict md;
	private zk zkClient = new zk();
	private volatile boolean flag = false;  	
	private Properties props; 
	private String jobKey;
	
	public MsLogPriser(){
	}
	
	public boolean init(String jobKey){
		this.jobKey = jobKey;
		zkClient.initCfg(jobKey);
		ConnStr = zkClient.getdbConStr();
		
        props = new Properties();
        //����brokerServer(kafka)ip��ַ
        props.put("bootstrap.servers", KafkaConfig.getInstance().getBootstrapServers());
        //����consumer group name
        props.put("group.id", jobKey);

        props.put("enable.auto.commit", "false");

        //����ʹ���ʼ��offsetƫ����Ϊ��group.id�����硣��������ã������latest����topic����һ����Ϣ��offset
        //�������latest��������ֻ�ܵõ�����������������������Ϣ
        props.put("auto.offset.reset", "earliest");
        props.put(ConsumerConfig.FETCH_MAX_BYTES_CONFIG, 6525000);
        props.put(ConsumerConfig.MAX_POLL_RECORDS_CONFIG, 1);
        props.put(ConsumerConfig.MAX_POLL_INTERVAL_MS_CONFIG, Integer.MAX_VALUE);
        //
        props.put("session.timeout.ms", "30000");
        props.put("key.deserializer", "org.apache.kafka.common.serialization.StringDeserializer");
        props.put("value.deserializer", "mak.triPart.MsTransPkgDeserializer");
        
        
		String host = StringUtil.getXmlValueFromStr(ConnStr, "host");
		String usrid = StringUtil.getXmlValueFromStr(ConnStr, "usrId");
		String pswd = StringUtil.getXmlValueFromStr(ConnStr, "pswd");
		String dbName = StringUtil.getXmlValueFromStr(ConnStr, "dbName");
		String logtype = StringUtil.getXmlValueFromStr(ConnStr, "logtype");
		try{
			MsDatabase _Db = new MsDatabase(new OutPutMgr(logtype), host, usrid, pswd, dbName);
			md = new MsDict(_Db);
			if (md.CheckDBState()){
				return md.RefreshDBDict();
			}else{
				return false;
			}
		}catch(Exception e){
			e.printStackTrace();
			logger.error("MsLogPriser��ȡ���ݿ��ṹʧ�ܣ���", e);
			return false;
		}
		
	}

	@Override
	public void run() {
		md.GetOutPut().Info(" MsLogPriser running......");
		KafkaConsumer<String, MsTransPkg> consumer = new KafkaConsumer<String, MsTransPkg>(props);
		consumer.subscribe(Arrays.asList(jobKey));
		while (true) {
			ConsumerRecords<String, MsTransPkg> records = consumer.poll(100);
			for (ConsumerRecord<String, MsTransPkg> record : records) {
				logger.info(record.key());
				MsTransPkg mPkg = record.value();
				logger.info("==============================");
				logger.info(mPkg.TransName);
				logger.info("==============================");
				// consumer.commitSync();
				
				MsTransPkgPrise MTPP = new MsTransPkgPrise(mPkg, md);			
				MTPP.start();
			}
			if (isTerminated()) {
				break;
			}
		}
		consumer.close();
	}

	public void Terminate() {
		flag = false;		
	}

	public boolean isTerminated() {
		return flag;
	}
}
