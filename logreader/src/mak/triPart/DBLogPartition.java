package mak.triPart;


import java.util.Map;

import org.apache.kafka.clients.producer.Partitioner;
import org.apache.kafka.common.Cluster;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class DBLogPartition implements Partitioner{
	private static Logger LOG = LoggerFactory.getLogger(DBLogPartition.class);
	@Override
	public void configure(Map<String, ?> arg0) {
		// TODO Auto-generated method stub
		
	}

	@Override
	public void close() {
		// TODO Auto-generated method stub
		
	}

	@Override
	public int partition(String topic, Object key, byte[] keyBytes, Object value, byte[] valueBytes, Cluster cluster) {
		// TODO Auto-generated method stub
//		List<PartitionInfo> partitions = cluster.partitionsForTopic(topic);
//        int numPartitions = partitions.size();
//        int partitionNum = 0;
//        try {
//            partitionNum = Integer.parseInt((String) key);
//        } catch (Exception e) {
//            partitionNum = key.hashCode() ;
//        }
//        LOG.info("the message sendTo topic:"+ topic+" and the partitionNum:"+ partitionNum);
//        return Math.abs(partitionNum  % numPartitions);
	    //根据key计算对应的partition
//		if (key.toString().equals("aaa"))
//			return 0;
//        else if (key.toString().equals("bbb"))
//            return 1;
//        else if (key.toString().equals("ccc"))
//            return 2;
//        else return 8;
		//TODO:全部放到partition 0
		return 0;		
	}

}
