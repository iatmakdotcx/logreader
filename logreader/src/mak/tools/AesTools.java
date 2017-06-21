package mak.tools;

import javax.crypto.BadPaddingException;
import javax.crypto.Cipher;
import javax.crypto.IllegalBlockSizeException;
import javax.crypto.spec.SecretKeySpec;
import java.util.Base64;

public class AesTools {
	private final String key = "0393201704251058";
	private Cipher Encipher;
	private Cipher Decipher;
	private static AesTools instance = new AesTools();
	
	public static AesTools getInstance() {
		return instance;
	}
	   
	public AesTools() {
		SecretKeySpec skeySpec = new SecretKeySpec(key.getBytes(), "AES");
		try {
			Encipher = Cipher.getInstance("AES");
			Encipher.init(Cipher.ENCRYPT_MODE, skeySpec);
			
			Decipher = Cipher.getInstance("AES");
			Decipher.init(Cipher.DECRYPT_MODE, skeySpec);
		} catch (Exception e) {
			e.printStackTrace();
		}
	}
	
	public String Encode(String buf){
		return Encode(buf.getBytes());
	}
	
	public String Encode(byte[] buf){
		String res = "";
		try {
			res = Base64Encode(Encipher.doFinal(buf));
		} catch (IllegalBlockSizeException | BadPaddingException e) {
			e.printStackTrace();
		}
		return res;
	}
	public String Decode(byte[] buf){
		return Decode(new String(buf));
	}
	public String Decode(String buf){
		String res = "";
		try {
			byte[] bufArr = Base64Decode(buf);
			res = new String(Decipher.doFinal(bufArr));
		} catch (IllegalBlockSizeException | BadPaddingException e) {
			e.printStackTrace();
		}
		return res;
	}
	
	public String Base64Encode(byte[] src)
	{
            return Base64.getEncoder().encodeToString(src);
	}
	public byte[] Base64Decode(String src)
	{
            return Base64.getDecoder().decode(src);
	}
}
