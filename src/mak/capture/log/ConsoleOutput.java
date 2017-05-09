package mak.capture.log;

public class ConsoleOutput implements Output {

	@Override
	public void Info(String var1) {
		// TODO Auto-generated method stub
		System.out.println(var1);
	}

	@Override
	public void Warning(String var1) {
		// TODO Auto-generated method stub
		System.out.println(var1);
	}

	@Override
	public void Error(String var1) {
		// TODO Auto-generated method stub
		System.err.println(var1);
	}

}
