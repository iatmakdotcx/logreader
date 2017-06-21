package mak.data.input;

public class ByteArrayByteStream implements ByteInputStream{
	protected byte buf[];
	protected int pos;
	protected int count;
	
	public ByteArrayByteStream(byte[] arr) {
        this.buf = arr;
        this.pos = 0;
        this.count = buf.length;
    }
	
	@Override
	public int readByte() {
		if (pos < count) {
			return buf[pos++] & 0xff;
		}else {
			throw new RuntimeException("EOF");
		}
	}
	
	@Override
	public int getBytesRead() {
		return pos;
	}

	@Override
	public int available() {
		return count - pos;
	}
	
	@Override
	public int seek(int Offset, SeekOrigin Origin) {
		switch (Origin) {
			case soFromBeginning:
				pos = Offset;
				break;
			case soFromCurrent:
				pos += Offset;  		
				break;
			case soFromEnd:
				pos = count + Offset;
				break;
		}
		return pos;
	}

}