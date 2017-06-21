package mak.data.input;

public  abstract interface ByteInputStream {
	public abstract int readByte();
	
	public abstract int getBytesRead();
	
	public abstract int available();
	
	public abstract int seek(int Offset, SeekOrigin Origin);
}
