update aac_9 set b='010101',c='00000',x='2015-01-01',v=2 where a_2=201


---checkpoint
select * from fn_dblog('0x0000003b:00000220:0004',null) where [Transaction ID]='0000:00000758'

insert aac_9 values('2018-05-04 15:44:23.333','201','111111111','cccccc    ','33333333',4,'2015-01-01需要在意講日文的速度嗎？--','222222222222222222')
delete aac_9 where a_2=201


---   1-1
begin tran 
save tran aaa
insert aac_9 values('2018-05-04 15:44:23.333','201','111111111','cccccc    ','33333333',4,'2015-01-01需要在意講日文的速度嗎？--','222222222222222222')
rollback tran aaa
commit tran

---   12
begin tran 
insert aac_9 values('2018-05-04 15:44:23.333','201','111111111','cccccc    ','33333333',4,'2015-01-01需要在意講日文的速度嗎？--','222222222222222222')
delete aac_9 where a_2=201
commit tran

---   12-2
begin tran 
insert aac_9 values('2018-05-04 15:44:23.333','201','111111111','cccccc    ','33333333',4,'2015-01-01需要在意講日文的速度嗎？--','222222222222222222')
save tran aaa
delete aac_9 where a_2=201
rollback tran aaa
commit tran
--     2-2
begin tran 
save tran aaa
delete aac_9 where a_2=201
rollback tran aaa
commit tran

begin tran 
update aac_9 set b='12345sdf6789',c='xxx',x='abcffdefghijklmn',v=200 where a_2=201
update aac_9 set b='111111111',c='cccccc',x='222222222222222222',v=3 where a_2=201
commit tran


--      3
update aac_9 set b='12345sdf6789',c='xxx',x='abcffdefghijklmn',v=200 where a_2=201
update aac_9 set b='111111111',c='cccccc',x='222222222222222222',v=3 where a_2=201

--      3-3
begin tran 
save tran aaa
update aac_9 set b='010101',c='00000',x='2015-01-01',v=2 where a_2=201
rollback tran aaa
commit tran

--   --      32
   begin tran 
   update aac_9 set b='12345sdf6789',c='xxx',x='abcffdefghijklmn',v=200 where a_2=201
   delete aac_9 where a_2=201
   commit tran

--      32-2
begin tran 
update aac_9 set b='010101',c='00000',x='2015-01-01',v=2 where a_2=201
save tran aaa
delete aac_9 where a_2=201
rollback tran aaa
commit tran

--      33
begin tran 
update aac_9 set b='12345sdf6789',c='xxx',x='abcffdefghijklmn',v=200 where a_2=201
save tran aaa
update aac_9 set b='111111111',c='cccccc',x='222222222222222222',v=3 where a_2=201
commit tran

--      33-3
---------------------VVVVVVVVVVVVVVVVV---------------------------有问题
begin tran 
update aac_9 set b='010101',c='00000',x='2015-01-01',v=2 where a_2=201
save tran aaa
update aac_9 set b='12345sdf6789',c='xxx',x='abcffdefghijklmn',v=200 where a_2=201
rollback tran aaa
commit tran

--      33-32
       begin tran 
       update aac_9 set b='111111111',c='cccccc',x='222222222222222222',v=3 where a_2=201
       save tran aaa
       update aac_9 set b='eeeeeeee',c='rrrrrrrr',x='ttttttttt',v=2 where a_2=201
       rollback tran aaa
       delete aac_9 where a_2=201
       commit tran

--      132
       begin tran 
       insert aac_9 values('2018-05-04 15:44:23.333','201','111111111','cccccc    ','33333333',4,'2015-01-01需要在意講日文的速度嗎？--','222222222222222222')
       update aac_9 set b='12345sdf6789',c='xxx',x='abcffdefghijklmn',v=200 where a_2=201
       delete aac_9 where a_2=201
       commit tran

--      13-32
     begin tran 
     insert aac_9 values('2018-05-04 15:44:23.333','201','111111111','cccccc    ','33333333',4,'2015-01-01需要在意講日文的速度嗎？--','222222222222222222')
     save tran aaa
     update aac_9 set b='12345sdf6789',c='xxx',x='abcffdefghijklmn',v=200 where a_2=201
     rollback tran aaa
     delete aac_9 where a_2=201
     commit tran

--      13-33-3
begin tran 
insert aac_9 values('2018-05-04 15:44:23.333','201','111111111','cccccc    ','33333333',4,'2015-01-01需要在意講日文的速度嗎？--','222222222222222222')
save tran aaa
update aac_9 set b='12345sdf6789',c='xxx',x='abcffdefghijklmn',v=200 where a_2=201
rollback tran aaa
save tran bbb
update aac_9 set b='eeeeeeee',c='rrrrrrrr',x='ttttttttt',v=2 where a_2=201
rollback tran bbb
commit tran

begin tran 
insert aac_9 values('2018-05-04 15:44:23.333','201','111111111','cccccc    ','33333333',4,'2015-01-01需要在意講日文的速度嗎？--','222222222222222222')
update aac_9 set b='eeeeeeee',c='rrrrrrrr',x='ttttttttt',v=2 where a_2=201
update aac_9 set w='qqqqqqqqqq' where a_2=201
update aac_9 set b='12345sdf6789',c='xxx',x='abcffdefghijklmn',v=200 where a_2=201
commit tran


--      133-33-3    delete aac_9 where a_2=201
begin tran 
insert aac_9 values('2018-05-04 15:44:23.333','201','111111111','cccccc    ','33333333',4,'2015-01-01需要在意講日文的速度嗎？--','222222222222222222')
update aac_9 set b='12345sdf6789',c='xxx',x='abcffdefghijklmn',v=200 where a_2=201
save tran aaa
update aac_9 set b='eeeeeeee',c='rrrrrrrr',x='ttttttttt',v=2 where a_2=201
rollback tran aaa
save tran bbb
update aac_9 set b='111111111',c='cccccc',x='222222222222222222',v=3 where a_2=201
rollback tran bbb
commit tran

--     --      13-33-32    delete aac_9 where a_2=201
     begin tran 
     insert aac_9 values('2018-05-04 15:44:23.333','201','111111111','cccccc    ','33333333',4,'2015-01-01需要在意講日文的速度嗎？--','222222222222222222')
     save tran aaa
     update aac_9 set b='12345sdf6789',c='xxx',x='abcffdefghijklmn',v=200 where a_2=201
     rollback tran aaa
     save tran bbb
     update aac_9 set b='eeeeeeee',c='rrrrrrrr',x='ttttttttt',v=2 where a_2=201
     rollback tran bbb
     update aac_9 set b='111111111',c='cccccc',x='222222222222222222',v=3 where a_2=201
     commit tran

--      133     delete aac_9 where a_2=201
begin tran 
insert aac_9 values('2018-05-04 15:44:23.333','201','111111111','cccccc    ','33333333',4,'2015-01-01需要在意講日文的速度嗎？--','222222222222222222')
update aac_9 set b='eeeeeeee',c='rrrrrrrr',x='ttttttttt',v=2 where a_2=201
update aac_9 set b='12345sdf6789',c='xxx',x='abcffdefghijklmn',v=200 where a_2=201
commit tran


--      1332
begin tran 
insert aac_9 values('2018-05-04 15:44:23.333','201','111111111','cccccc    ','33333333',4,'2015-01-01需要在意講日文的速度嗎？--','222222222222222222')
update aac_9 set b='eeeeeeee',c='rrrrrrrr',x='ttttttttt',v=2 where a_2=201
update aac_9 set b='12345sdf6789',c='xxx',x='abcffdefghijklmn',v=200 where a_2=201
delete aac_9 where a_2=201
commit tran
--      12-232
begin tran 
insert aac_9 values('2018-05-04 15:44:23.333','201','111111111','cccccc    ','33333333',4,'2015-01-01需要在意講日文的速度嗎？--','222222222222222222')
save tran aaa
delete aac_9 where a_2=201
rollback tran aaa
update aac_9 set b='eeeeeeee',c='rrrrrrrr',x='ttttttttt',v=2 where a_2=201
delete aac_9 where a_2=201
commit tran
--      *132-2
begin tran 
insert aac_9 values('2018-05-04 15:44:23.333','201','111111111','cccccc    ','33333333',4,'2015-01-01需要在意講日文的速度嗎？--','222222222222222222')
update aac_9 set b='eeeeeeee',c='rrrrrrrr',x='ttttttttt',v=2 where a_2=201
save tran aaa
delete aac_9 where a_2=201
rollback tran aaa
commit tran

--      1332-2
begin tran 
insert aac_9 values('2018-05-04 15:44:23.333','201','111111111','cccccc    ','33333333',4,'2015-01-01需要在意講日文的速度嗎？--','222222222222222222')
update aac_9 set b='eeeeeeee',c='rrrrrrrr',x='ttttttttt',v=2 where a_2=201
update aac_9 set b='12345sdf6789',c='xxx',x='abcffdefghijklmn',v=200 where a_2=201
save tran aaa
delete aac_9 where a_2=201
rollback tran aaa
commit tran

--      12123
begin tran 
insert aac_9 values('2018-05-04 15:44:23.333','201','111111111','cccccc    ','33333333',4,'2015-01-01需要在意講日文的速度嗎？--','222222222222222222')
delete aac_9 where a_2=201

insert aac_9 values('2018-05-04 15:44:23.333','201','111111111','cccccc    ','33333333',4,'2015-01-01需要在意講日文的速度嗎？--','222222222222222222')
delete aac_9 where a_2=201
update aac_9 set b='12345sdf6789',c='xxx',x='abcffdefghijklmn',v=200 where a_2=201
commit tran
--  
begin tran 
insert aac_9 values('2018-05-04 15:44:23.333','201','111111111','cccccc    ','33333333',4,'2015-01-01需要在意講日文的速度嗎？--','222222222222222222')
save tran aaa
delete aac_9 where a_2=201
insert aac_9 values('2018-05-04 15:44:23.333','201','111111111','cccccc    ','33333333',4,'2015-01-01需要在意講日文的速度嗎？--','222222222222222222')
delete aac_9 where a_2=201
rollback tran aaa
update aac_9 set b='12345sdf6789',c='xxx',x='abcffdefghijklmn',v=200 where a_2=201
commit tran


--      132-23
begin tran 
insert aac_9 values('2018-05-04 15:44:23.333','201','111111111','cccccc    ','33333333',4,'2015-01-01需要在意講日文的速度嗎？--','222222222222222222')
update aac_9 set b='12345sdf6789',c='xxx',x='abcffdefghijklmn',v=200 where a_2=201
save tran aaa
delete aac_9 where a_2=201
rollback tran aaa
update aac_9 set b='eeeeeeee',c='rrrrrrrr',x='ttttttttt',v=2 where a_2=201
commit tran


--    32-23
begin tran 
update aac_9 set b='12345sdf6789',c='xxx',x='abcffdefghijklmn',v=200 where a_2=201
save tran aaa
delete aac_9 where a_2=201
rollback tran aaa
update aac_9 set b='111111111',c='cccccc',x='222222222222222222',v=3 where a_2=201
commit tran

--   33
begin tran 
update aac_9 set b='eeeeeeee',c='rrrrrrrr',x='ttttttttt',v=2 where a_2=201
update aac_9 set b='1111x11111',c='cccxccc',x='2222x22222222222222',v=3 where a_2=201
commit tran

--   2-23
begin tran 
save tran aaa
delete aac_9 where a_2=201
rollback tran aaa
update aac_9 set b='111111111',c='cccccc',x='222222222222222222',v=3 where a_2=201
commit tran

--   2-232-2
begin tran 
save tran aaa
delete aac_9 where a_2=201
rollback tran aaa
update aac_9 set b='eeeeeeee',c='rrrrrrrr',x='ttttttttt',v=2 where a_2=201
save tran bbb
delete aac_9 where a_2=201
rollback tran bbb
commit tran
















