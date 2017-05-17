package mak.triPart;

import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.io.ObjectInputStream;
import java.util.Map;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import mak.capture.mssql.MsTransPkg;

public class MsTransPkgDeserializer implements org.apache.kafka.common.serialization.Deserializer<MsTransPkg>  {
	private static Logger Logger = LoggerFactory.getLogger(MsTransPkgDeserializer.class);
	@Override
	public void close() {
		// TODO Auto-generated method stub
		
	}

	@Override
	public void configure(Map<String, ?> arg0, boolean arg1) {
		// TODO Auto-generated method stub
		
	}

	@Override
	public MsTransPkg deserialize(String arg0, byte[] arg1) {
		try {
			ByteArrayInputStream ins = new ByteArrayInputStream(arg1);  
			ObjectInputStream ois = new ObjectInputStream(ins);
			MsTransPkg mTransPkg = (MsTransPkg)ois.readObject();
			ins.close();
			ois.close();
			return mTransPkg;
		} catch (IOException | ClassNotFoundException e) {
			Logger.error("∑¥–Ú¡–ªØ ß∞‹£°", e);
		}  
		return null;
	}

}
