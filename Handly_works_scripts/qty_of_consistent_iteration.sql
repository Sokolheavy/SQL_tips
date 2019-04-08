		-- 'rn' - consistent numeration of dates,
		-- 'grp' - diff beetwen dates and 'rn', if dates are consistent, 'grp' is equal for this dates

	;WITH groups AS (
		SELECT
			distinct convert(date, operdate) operdate,
			dealid,
			id_order,
			DENSE_RANK() OVER (partition by dealid, id_order ORDER BY convert(date, operdate)) AS rn,
			dateadd(day, -DENSE_RANK() OVER (partition by dealid, id_order ORDER BY convert(date, operdate)), convert(date, operdate)) AS grp
		from #temp_provodki
		where description='Расход')

	select groups2.dealid,
		groups2.id_order,
		max(groups2.consecutiveDates) Max_consecutive_Dates
	into #Max_consecutiveDates_all
	from(
		select 
			dealid,
			id_order,
			count(*) AS consecutiveDates,
			MIN(operdate) AS minDate,
			MAX(operdate) AS maxDate
		FROM groups
		GROUP BY dealid,
	        id_order,
	        grp) groups2
	GROUP BY groups2.dealid,
        groups2.id_order
