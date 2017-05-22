/*
 * To change this license header, choose License Headers in Project Properties.
 * To change this template file, choose Tools | Templates
 * and open the template in the editor.
 */
package mak.capture;

/**
 *
 * @author Chin
 */
public interface DBLogPicker extends Runnable {
	public boolean init(String jobKey);
	public void Terminate();
	public boolean isTerminated();
	
}
