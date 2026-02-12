USE TMR_EXAMPLE;
GO

IF OBJECT_ID('dbo.LossTimePairs2', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.LossTimePairs2 (
        id INT IDENTITY(1,1) PRIMARY KEY,

        line VARCHAR(10) NOT NULL,
        workingStation INT NOT NULL,
        problem INT NOT NULL,

        windowStart DATETIME NOT NULL,
        windowEnd   AS (DATEADD(MINUTE, 30, windowStart)) PERSISTED,

        durationSec INT NOT NULL DEFAULT(0),
        durationMinDecimal AS (durationSec / 60.0) PERSISTED,

        -- untuk info tambahan (karena ini tabel summary)
        firstOnTime DATETIME NULL,
        lastOffTime DATETIME NULL,

        lastUpdate DATETIME NOT NULL DEFAULT(GETDATE())
    );

    CREATE UNIQUE INDEX uq_LossTimePairs2_key
    ON dbo.LossTimePairs2(line, workingStation, problem, windowStart);
END
GO
CREATE OR ALTER TRIGGER dbo.trg_UpdateLossTimePairs2_30Min
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
            o.workingStation,
            o.problem,
            onEvt.onTime,
            o.offTime,
            DATEDIFF(SECOND, onEvt.onTime, o.offTime) AS durationSec,

            -- windowStart 30 menit berdasarkan OFF time (bucket fixed dari jam 00)
            DATEADD(
                MINUTE,
                (DATEDIFF(MINUTE, 0, o.offTime) / 30) * 30,
                0
            ) AS windowStart
        FROM OffRows o
        CROSS APPLY (
            SELECT TOP (1) e.eventTime AS onTime
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
    MERGE dbo.LossTimePairs2 AS tgt
    USING (
        SELECT
            line,
            workingStation,
            problem,
            windowStart,
            SUM(durationSec) AS durationSec,
            MIN(onTime) AS firstOnTime,
            MAX(offTime) AS lastOffTime
        FROM Pairs
        GROUP BY line, workingStation, problem, windowStart
    ) src
    ON  tgt.line = src.line
    AND tgt.workingStation = src.workingStation
    AND tgt.problem = src.problem
    AND tgt.windowStart = src.windowStart
    WHEN MATCHED THEN
        UPDATE SET
            tgt.durationSec = tgt.durationSec + src.durationSec,
            tgt.firstOnTime = CASE
                                WHEN tgt.firstOnTime IS NULL OR src.firstOnTime < tgt.firstOnTime
                                THEN src.firstOnTime
                                ELSE tgt.firstOnTime
                              END,
            tgt.lastOffTime = CASE
                                WHEN tgt.lastOffTime IS NULL OR src.lastOffTime > tgt.lastOffTime
                                THEN src.lastOffTime
                                ELSE tgt.lastOffTime
                              END,
            tgt.lastUpdate = GETDATE()
    WHEN NOT MATCHED THEN
        INSERT (
            line, workingStation, problem,
            windowStart, durationSec,
            firstOnTime, lastOffTime,
            lastUpdate
        )
        VALUES (
            src.line, src.workingStation, src.problem,
            src.windowStart, src.durationSec,
            src.firstOnTime, src.lastOffTime,
            GETDATE()
        );
END;
GO

USE TMR_EXAMPLE;
GO

DECLARE @line VARCHAR(10) = '2T';   -- ganti 'SKD' untuk test SKD

WITH Bucket AS (
    SELECT
        line,
        workingStation,
        problem,
        durationSec,
        DATEADD(minute, DATEDIFF(minute, 0, onTime) / 5 * 5, 0) AS windowStart
    FROM LossTimePairs2
    WHERE line = @line
)
SELECT
    workingStation,
    problem,
    SUM(durationSec) AS totalSec,
    CAST(ROUND(SUM(durationSec) / 60.0, 2) AS DECIMAL(10,2)) AS totalMin
FROM Bucket
WHERE windowStart = DATEADD(minute, DATEDIFF(minute, 0, GETDATE()) / 5 * 5, 0)
GROUP BY workingStation, problem
ORDER BY workingStation, problem;

USE TMR_EXAMPLE;
GO

DECLARE @line VARCHAR(10) = '2T';  -- ganti 'SKD' untuk SKD

SELECT
    workingStation,
    problem,
    SUM(durationSec) AS totalSec,
    CAST(ROUND(SUM(durationSec) / 60.0, 2) AS DECIMAL(10,2)) AS totalMin
FROM dbo.LossTimePairs2
WHERE line = @line
  AND windowStart = DATEADD(
        minute,
        DATEDIFF(minute, 0, GETDATE()) / 30 * 30,
        0
      )
GROUP BY workingStation, problem
ORDER BY workingStation, problem;

USE TMR_EXAMPLE;
GO

DECLARE @line VARCHAR(10) = '2T';

SELECT
    workingStation,
    problem,
    SUM(durationSec) AS totalSec,
    CAST(ROUND(SUM(durationSec) / 60.0, 2) AS DECIMAL(10,2)) AS totalMin
FROM dbo.LossTimePairs2
WHERE line = @line
  AND windowStart = DATEADD(
        minute,
        DATEDIFF(minute, 0, GETDATE()) / 30 * 30,
        0
      )
GROUP BY workingStation, problem
ORDER BY workingStation, problem;
