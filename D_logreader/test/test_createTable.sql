select AllocUnitName,* from fn_dblog('0x0000003c:00000140:001b',null) where [Transaction ID]='0000:0000079d'
--select * from fn_dblog('0x0000003c:00000140:001b',null) where [Transaction ID]='0000:0000079E'
select * from fn_dblog('0x0000003c:00000140:001b',null) where [Transaction ID]='0000:0000079F'
checkpoint

CREATE TABLE [dbo].[tc_heap](
	[id] [int] NOT NULL,
	[dm] [varchar](50) NULL,
	[mc] [varchar](50) NULL,
)

drop table [tc_heap]