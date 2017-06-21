package mak.data.input;

public abstract interface LittleEndianAccessor
{
  /**
   * 读取一个字节
   * @return
   */
  public abstract byte readByte();
  
  public abstract char readChar();

  public abstract short readShort();

  public abstract int readInt();

  public abstract long readLong();
  /**
   * 跳过指定字节
   * @param paramInt
   */
  public abstract void skip(int paramInt);
  /**
   * 读取指定数量的数据
   * @param 要读取的字节数
   * @return
   */
  public abstract byte[] read(int paramInt);
 
  public abstract float readFloat();

  public abstract double readDouble();
  
  public abstract String readAsciiString(int paramInt);

  public abstract String readNullTerminatedAsciiString();
  /**
   * 读取一个包含1位长度头的字符串
   *
   */
  public abstract String readL1String();
  /**
   * 读取一个包含2位长度头的字符串
   *
   */
  public abstract String readL2String();
  /**
   * 读取一个包含4位长度头的字符串
   *
   */
  public abstract String readL4String();
  /**
   * 获取已读取的字节数
   * @return
   */
  public abstract int getBytesRead();
  /**
   * 获取可读取的字节数
   * @return
   */
  public abstract int available();
}