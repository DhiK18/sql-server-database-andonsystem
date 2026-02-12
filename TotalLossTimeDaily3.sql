USE TMR_EXAMPLE;
GO

IF OBJECT_ID('dbo.TotalLossTimeDaily3', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.TotalLossTimeDaily3 (
        id INT IDENTITY(1,1) PRIMARY KEY,

        line VARCHAR(10) NOT NULL,   -- 2T / SKD
        problem INT NOT NULL,

        periodStart DATETIME NOT NULL,
        periodEnd   DATETIME NOT NULL,

        durationSeconds INT NOT NULL DEFAULT(0),
        lossMinutes DECIMAL(10,2) NOT NULL DEFAULT(0.00),

        lastUpdate DATETIME NOT NULL DEFAULT(GETDATE())
    );

    CREATE UNIQUE INDEX uq_TotalLossTimeDaily3
    ON dbo.TotalLossTimeDaily3(line, problem, periodStart);
END
GO


CREATE OR ALTER TRIGGER dbo.trg_UpdateTotalLossTimeDaily3
ON dbo.LossTimeEvents
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    -- hanya proses OFF
    IF NOT EXISTS (SELECT 1 FROM inserted WHERE value = 0)
        RETURN;

    ;WITH OffRows AS (
        SELECT
            i.line,
            i.workingStation,
            i.problem,
            i.eventTime AS offTime
        FROM inserted i
        WHERE i.value = 0
    ),
    Pairs AS (
        SELECT
            o.line,
            o.problem,

            onEvt.onTime,
            o.offTime,

            DATEDIFF(SECOND, onEvt.onTime, o.offTime) AS durationSeconds,

            -- PERIOD 1 HARI (reset 24 jam dari jam 00:00) berdasarkan offTime
            DATEADD(DAY, DATEDIFF(DAY, 0, o.offTime), 0) AS periodStart
        FROM OffRows o
        CROSS APPLY (
            SELECT TOP (1)
                e.eventTime AS onTime
            FROM dbo.LossTimeEvents e
            WHERE e.line = o.line
              AND e.workingStation = o.workingStation
              AND e.problem = o.problem
              AND e.value = 1
              AND e.eventTime < o.offTime
            ORDER BY e.eventTime DESC
        ) onEvt
        WHERE onEvt.onTime IS NOT NULL
          AND o.offTime > onEvt.onTime
    )
    MERGE dbo.TotalLossTimeDaily3 AS tgt
    USING (
        SELECT
            line,
            problem,
            periodStart,
            DATEADD(DAY, 1, periodStart) AS periodEnd,
            SUM(durationSeconds) AS durationSeconds,
            SUM(durationSeconds) / 60.0 AS lossMinutes
        FROM Pairs
        GROUP BY line, problem, periodStart
    ) src
    ON tgt.line = src.line
   AND tgt.problem = src.problem
   AND tgt.periodStart = src.periodStart
    WHEN MATCHED THEN
        UPDATE SET
            tgt.durationSeconds = tgt.durationSeconds + src.durationSeconds,
            tgt.lossMinutes     = tgt.lossMinutes + src.lossMinutes,
            tgt.lastUpdate      = GETDATE()
    WHEN NOT MATCHED THEN
        INSERT (
            line,
            problem,
            periodStart,
            periodEnd,
            durationSeconds,
            lossMinutes,
            lastUpdate
        )
        VALUES (
            src.line,
            src.problem,
            src.periodStart,
            src.periodEnd,
            src.durationSeconds,
            src.lossMinutes,
            GETDATE()
        );
END;
GO

