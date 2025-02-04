/*
Copyright (c) 2020 Darling Data, LLC

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/


/*
This is a helper view I use in some of my presentations to look at what's in memory.

I probably wouldn't run this in production, especially on servers with a lot of memory in them.

The dm_os_buffer_descriptors DMV especially can be really slow at times
*/

IF OBJECT_ID('dbo.WhatsUpMemory') IS NULL
BEGIN
DECLARE @vsql NVARCHAR(MAX) = 
    N'
CREATE VIEW dbo.WhatsUpMemory
    AS
SELECT 1 AS x;
    ';

PRINT @vsql;
EXEC (@vsql);
END;
GO 


ALTER VIEW dbo.WhatsUpMemory
AS
SELECT TOP (2147483647)
    N'WhatsUpMemory' AS view_name,
    DB_NAME() AS database_name,
    SCHEMA_NAME(x.schema_id) AS schema_name,
    x.object_name,
    x.index_name,    
    in_row_pages_mb = 
        SUM
        (
            CASE 
                WHEN x.type IN (1, 3) 
                THEN 1 
                ELSE 0 
            END
        ) * 8. / 1024.,
    lob_pages_mb = 
        SUM
        (
            CASE 
                WHEN x.type = 2 
                THEN 1 
                ELSE 0 
            END
        ) * 8. / 1024.,
    buffer_cache_pages_total = 
        COUNT_BIG(*)
FROM 
(
    SELECT       
        o.schema_id,
        o.name AS object_name,
        i.name AS index_name,
        au.type,
        au.allocation_unit_id 
    FROM sys.allocation_units AS au
    INNER JOIN sys.partitions AS p
        ON au.container_id = p.hobt_id 
        AND au.type =1
    INNER JOIN sys.objects AS o
        ON p.object_id = o.object_id
    INNER JOIN sys.indexes AS i
        ON  o.object_id = i.object_id
        AND p.index_id = i.index_id
    WHERE au.type > 0
    AND   o.is_ms_shipped = 0
    
    UNION ALL
    
    SELECT       
        o.schema_id,
        o.name AS object_name,
        i.name AS index_name,
        au.type,
        au.allocation_unit_id 
    FROM sys.allocation_units AS au
    INNER JOIN sys.partitions AS p
        ON au.container_id = p.hobt_id 
        AND au.type = 3
    INNER JOIN sys.objects AS o
        ON p.object_id = o.object_id
    INNER JOIN sys.indexes AS i
        ON  o.object_id = i.object_id
        AND p.index_id = i.index_id
    WHERE au.type > 0
    AND   o.is_ms_shipped = 0
    
    UNION ALL
    
    SELECT       
        o.schema_id,
        o.name AS object_name,
        i.name AS index_name,
        au.type,
        au.allocation_unit_id 
    FROM sys.allocation_units AS au
    INNER JOIN sys.partitions AS p
        ON au.container_id = p.partition_id 
        AND au.type = 2
    INNER JOIN sys.objects AS o
        ON p.object_id = o.object_id
    INNER JOIN sys.indexes AS i
        ON  o.object_id = i.object_id
        AND p.index_id = i.index_id
    WHERE au.type > 0
    AND   o.is_ms_shipped = 0
) AS x
JOIN sys.dm_os_buffer_descriptors AS obd
    ON x.allocation_unit_id = obd.allocation_unit_id
GROUP BY 
    SCHEMA_NAME(x.schema_id), 
    x.object_name, 
    x.index_name
ORDER BY COUNT_BIG(*) DESC;
GO

