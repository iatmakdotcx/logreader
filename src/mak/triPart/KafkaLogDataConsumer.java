package mak.triPart;

import java.util.Arrays;
import java.util.Properties;

import org.apache.kafka.clients.consumer.ConsumerRecord;
import org.apache.kafka.clients.consumer.ConsumerRecords;
import org.apache.kafka.clients.consumer.KafkaConsumer;
import org.apache.log4j.PropertyConfigurator;
import org.apache.kafka.clients.consumer.ConsumerConfig;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import mak.capture.mssql.MsTransPkg;

public class KafkaLogDataConsumer {
	private static Logger Logger = LoggerFactory.getLogger(KafkaLogDataConsumer.class);
    public KafkaLogDataConsumer() {
        // TODO Auto-generated constructor stub
    }

    public static void main(String[] args) {
    	PropertyConfigurator.configure("config/log4j.properties");
        Properties props = new Properties();
        //����brokerServer(kafka)ip��ַ
        props.put("bootstrap.servers", KafkaConfig.getInstance().getBootstrapServers());
        //����consumer group name
        props.put("group.id","test");

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
        KafkaConsumer<String ,MsTransPkg> consumer = new KafkaConsumer<String ,MsTransPkg>(props);
        consumer.subscribe(Arrays.asList("ssss"));
        while (true) {
        	
             ConsumerRecords<String, MsTransPkg> records = consumer.poll(100);
             for (ConsumerRecord<String, MsTransPkg> record : records) {
            	 Logger.info(record.key());
            	 MsTransPkg mPkg = record.value();
            	 Logger.info("==============================");
            	 Logger.info(mPkg.TransName);
            	 Logger.info("==============================");
                 //consumer.commitSync();
             }
         }
    }
}
