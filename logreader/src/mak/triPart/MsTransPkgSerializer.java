package mak.triPart;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.ObjectOutputStream;
import java.util.Map;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import mak.capture.mssql.MsTransPkg;

public class MsTransPkgSerializer implements org.apache.kafka.common.serialization.Serializer<MsTransPkg> {
	private static Logger logger = LoggerFactory.getLogger(MsTransPkgSerializer.class);
	@Override
	public void close() {
		// TODO Auto-generated method stub
		
	}

	@Override
	public void configure(Map<String, ?> arg0, boolean arg1) {
		// TODO Auto-generated method stub
		
	}

	@Override
	public byte[] serialize(String arg0, MsTransPkg arg1) {
		try {
			ByteArrayOutputStream bos = new ByteArrayOutputStream();  
			ObjectOutputStream o = new ObjectOutputStream( bos);
			o.writeObject(arg1);   //写入数据  
			o.flush(); 
			o.close();  
			byte[] b = bos.toByteArray();
			bos.close();
			return b;
		} catch (IOException e) {
			logger.error("序列化失败！", e);
		}     
		return new byte[0];
	}

}
