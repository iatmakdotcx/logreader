select AllocUnitName,* from fn_dblog('0x0000003e:00000238:0001',null) where [Transaction ID]='0000:00000839'
--select * from fn_dblog('0x0000003c:00000140:001b',null) where [Transaction ID]='0000:0000079E'
select * from fn_dblog('0x0000003e:00000360:0001',null)  
checkpoint


CREATE TABLE [dbo].[tc_heap](
	[id] [int] NOT NULL,
	[dm] [varchar](50) COLLATE Japanese_CI_AS NULL,
	[mc] [varchar](50) NULL,
)
drop table [tc_heap]

CREATE TABLE [dbo].[tc_heap_pk](
	[id] [int] NOT NULL primary key,
	[dm] [varchar](50) NULL,
	[mc] [varchar](50) NULL,
)
drop table [tc_heap_pk]

CREATE TABLE [dbo].[tc_heap_pki](
	[id] [int] NOT NULL primary key identity(66,77),
	[dm] [varchar](50) NULL,
	[mc] [varchar](50) NULL,
)
drop table [tc_heap_pki]


CREATE TABLE [dbo].[tc_all](
	[id] [int] NULL,
	[bint] [bigint] NULL,
	[bin50] [binary](50) NULL,
	[b] [bit] NULL,
	[c] [char](10) NULL,
	[date] [date] NULL,
	[datetime] [datetime] NULL,
	[datetime27] [datetime2](7) NULL,
	[datetimeoffset(7)] [datetimeoffset](7) NULL,
	[decimal(18, 4)] [decimal](18, 4) NULL,
	[float] [float] NULL,
	[image] [image] NULL,
	[money] [money] NULL,
	[nchar(10)] [nchar](10) NULL,
	[ntext] [ntext] NULL,
	[numeric(18, 5)] [numeric](18, 5) NULL,
	[nvarchar(50)] [nvarchar](50) NULL,
	[nvarchar(MAX)] [nvarchar](max) NULL,
	[real] [real] NULL,
	[smalldatetime] [smalldatetime] NULL,
	[sql_variant] [sql_variant] NULL,
	[text] [text] NULL,
	[time(7)] [time](7) NULL,
	[timestamp] [timestamp] NULL,
	[tinyint] [tinyint] NULL,
	[uniqueidentifier] [uniqueidentifier] NULL,
	[varbinary(50)] [varbinary](50) NULL,
	[varbinary(MAX)] [varbinary](max) NULL,
	[varchar(50)] [varchar](50) NULL,
	[varchar(MAX)] [varchar](max) NULL,
	[xml] [xml] NULL,
	[geography] [geography] NULL
)


alter table [dbo].[tc_heap]	alter column [dm] [varchar](50) COLLATE Japanese_CI_AS not NULL
alter table [dbo].[tc_heap]	alter column [dm] [varchar](150) COLLATE Japanese_CI_AS NULL

Alter table [tc_heap] add constraint ix_id unique CLUSTERED(id asc,dm desc)
ALTER TABLE [dbo].[tc_heap] ADD CONSTRAINT [ix_id] UNIQUE NONCLUSTERED (id ASC) 


Alter table [tc_heap] drop constraint ix_id 


ALTER TABLE [dbo].[tc_heap] ADD CONSTRAINT [pk_id] primary key NONCLUSTERED (id ASC) 
ALTER TABLE [dbo].[tc_heap] ADD CONSTRAINT [pk_id] primary key CLUSTERED (id ASC) 
ALTER TABLE [dbo].[tc_heap] ADD CONSTRAINT [pk_id] primary key NONCLUSTERED (id ASC,dm desc) 
ALTER TABLE [dbo].[tc_heap] ADD CONSTRAINT [pk_id] primary key CLUSTERED (id ASC,dm desc) 

Alter table [tc_heap] drop constraint pk_id 

ALTER TABLE [dbo].[tc_heap] ADD CONSTRAINT [df_dm] default('111') for dm

ALTER TABLE [dbo].[tc_heap] ADD CONSTRAINT [ck_dm] check(dm<>'123')
ALTER TABLE [dbo].[tc_heap] ADD CONSTRAINT [ck_dm] CHECK(([dm]<>'123')) 


Alter table [tc_heap] drop constraint [CK_dm] 


exec sp_rename '[dbo].[tc_heap_R]','[dbo].[tc_heap]';
exec sp_rename '[dbo].[tc_heap]','tc_heap_R';
exec sp_rename '[dbo].[[dbo]].[tc_heap]]]','tc_heap';


exec sp_rename 'tc_heap','[dbo].[tc_heap_R]';
exec sp_rename '[dbo].[tc_heap_R]','[dbo].[tc_heap]';
exec sp_rename '[dbo].[tc_heap]','[dbo].[tc_heap].[mc1]','column'
EXEC sp_rename 'dbo.tc_heap.[[dbo]].[tc_heap]].[mc1]]]', 'mc2', 'COLUMN' 



exec sp_rename '[dbo].[tc_heap].[mc301]','mc32';
exec sp_rename '[dbo].[tc_heap].[mc32]','mc301';



select object_id('dbo.tc_heap.[[dbo]].[tc_heap]].[mc1]]]')
select OBJECT_NAME(350624292)

 
Create table tc_fixedC
(
  id int primary key,
  dm char(20),
  mc char(20),
  pym char(30)
)


alter table tc_fixedC add zjm char(200) 

alter table tc_fixedC add dm char(200)

alter table tc_fixedC alter column zjm char(220) not null

ALTER TABLE [dbo].[tc_fixedC] alter column [dm] char(20) COLLATE Chinese_PRC_CI_AS not NULL
ALTER TABLE [dbo].[tc_fixedC] alter column [dm] [CHAR](10) COLLATE Japanese_CI_AS NULL

alter table tc_fixedC drop column zjm

select * from sys.objects where name='tc_fixedC'

ALTER TABLE [dbo].[tc_fixedC] alter column [dm] [CHAR](200) COLLATE Chinese_PRC_CI_AS NOT NULL


drop table tc_fixedC


select object_name(1714105147)

begin tran
Create table tc_fixedC
(
  id int primary key,
  dm char(20),
  mc char(20),
  pym char(30)
)

alter table tc_fixedC add zjm char(200) 
commit tran

 select a.id,a.colid from sysindexkeys a join sys.indexes b on a.id=b.object_id and a.indid=b.index_id and is_unique=1 and [type]=1 and a.id=1070626857 order by a.id,keyno

