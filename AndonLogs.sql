USE [ANDONSYSTEM];
GO

IF OBJECT_ID('[dbo].[AndonLogs]', 'U') IS NOT NULL
    DROP TABLE [dbo].[AndonLogs];
GO

CREATE TABLE [dbo].[AndonLogs] (
    [id]            BIGINT IDENTITY(1,1) NOT NULL,
    [line]          NVARCHAR(50)  NULL,
    [workingStation] NVARCHAR(50) NULL,   
    [problem]       NVARCHAR(50)  NULL,   
    [value]         NVARCHAR(50)  NULL,   
    [created_at]    DATETIME2(0)  NOT NULL CONSTRAINT [DF_AndonLogs_created_at] DEFAULT (SYSUTCDATETIME()),
    [valueString]   NVARCHAR(255) NULL,
    [valueInt]      INT           NULL,

    CONSTRAINT [PK_AndonLogs] PRIMARY KEY CLUSTERED ([id] ASC)
);
GO

CREATE INDEX [IX_AndonLogs_created_at]
ON [dbo].[AndonLogs] ([created_at] DESC);
GO

CREATE INDEX [IX_AndonLogs_ws_problem_time]
ON [dbo].[AndonLogs] ([workingStation], [problem], [created_at] DESC);
GO
