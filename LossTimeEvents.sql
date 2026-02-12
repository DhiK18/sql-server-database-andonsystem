CREATE TABLE dbo.LossTimeEvents (
    id BIGINT IDENTITY(1,1) PRIMARY KEY,
    line NVARCHAR(50) NOT NULL,
    workingStation INT NOT NULL,
    problem INT NOT NULL,
    value BIT NOT NULL,
    eventTime DATETIME2(3) NOT NULL CONSTRAINT DF_LossTimeEvents_eventTime DEFAULT SYSUTCDATETIME()
);

CREATE INDEX IX_LossTimeEvents_LineWsProbTime
ON dbo.LossTimeEvents (line, workingStation, problem, eventTime DESC)
INCLUDE (value);
