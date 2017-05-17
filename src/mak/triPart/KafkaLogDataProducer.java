package mak.triPart;

import java.util.Properties;

import org.apache.kafka.clients.producer.Callback;
import org.apache.kafka.clients.producer.KafkaProducer;
import org.apache.kafka.clients.producer.ProducerConfig;
import org.apache.kafka.clients.producer.ProducerRecord;
import org.apache.kafka.clients.producer.RecordMetadata;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import mak.capture.mssql.MsTransPkg;


public class KafkaLogDataProducer {
	private static Logger LOG = LoggerFactory.getLogger(KafkaLogDataProducer.class);
	private static KafkaLogDataProducer instance = new KafkaLogDataProducer();
	private Properties props;
	private String Topic;
	
	public KafkaLogDataProducer(){
		
	}
	
	public static KafkaLogDataProducer getInstance() {
		return instance;
	}
	   
	public boolean init(String Topic){
		//Topic¾ÍÊÇjobKey
		this.Topic = Topic;
		props = new Properties();
        
        props.put("bootstrap.servers", KafkaConfig.getInstance().getBootstrapServers());
        
        props.put("retries", Integer.MAX_VALUE);
        props.put(ProducerConfig.ACKS_CONFIG, "all");
        props.put(ProducerConfig.MAX_IN_FLIGHT_REQUESTS_PER_CONNECTION, 1);
        // props.put("batch.size", 16384);
        props.put("linger.ms", 1);
        // props.put("buffer.memory", 33554432);
        
        props.put("key.serializer", "org.apache.kafka.common.serialization.StringSerializer");
        props.put("value.serializer", "mak.triPart.MsTransPkgSerializer");
        //props.put("partitioner.class", "mak.triPart.DBLogPartition");
        
		return true;
	}
	
	public boolean SendData(MsTransPkg pkg){
		final KafkaProducer<String, MsTransPkg> producer = new KafkaProducer<String, MsTransPkg>(props);
		ProducerRecord<String, MsTransPkg> record = new ProducerRecord<String, MsTransPkg>(Topic, pkg.TransName, pkg);
		producer.send(record, new Callback() {
		    @Override
		    public void onCompletion(RecordMetadata metadata, Exception e) {
		        if (e != null)
		            LOG.error("the producer has a error:" + e.getMessage());
		        else {
		            LOG.info("The offset of the record we just sent is: " + metadata.offset());
		            LOG.info("The partition of the record we just sent is: " + metadata.partition());
		        }
		        producer.close();
		    }
		});
		return true;
	}
	
}
