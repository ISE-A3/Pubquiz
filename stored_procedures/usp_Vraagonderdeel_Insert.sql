USE BANG;
GO

/*
INSERT VRAAGONDERDEEL
*/

CREATE or ALTER PROCEDURE dbo.usp_Vraagonderdeel_Insert
	@VRAAG_NAAM varchar(256),
	@VRAAGONDERDEELNUMMER int,
	@VRAAGONDERDEEL varchar(256),
	@VRAAGSOORT char(1)
AS
BEGIN  
	DECLARE @savepoint varchar(128) = CAST(OBJECT_NAME(@@PROCID) as varchar(125)) + CAST(@@NESTLEVEL AS varchar(3))
	DECLARE @startTrancount int = @@TRANCOUNT;
	BEGIN TRY
		BEGIN TRANSACTION
		SAVE TRANSACTION @savepoint
		DECLARE @VRAAG_ID INT
		SET @VRAAG_ID = (SELECT VRAAG_ID
						FROM VRAAG
						WHERE VRAAG_NAAM = @VRAAG_NAAM)

		--checks hier
		IF NOT EXISTS (
			SELECT ''
			FROM VRAAG
			WHERE VRAAG_NAAM = @VRAAG_NAAM
			)
			THROW 50001, 'Er bestaat nog geen vraag voor dit vraagonderdeel', 1;

		IF EXISTS (
			SELECT ''
			FROM VRAAGONDERDEEL
			WHERE VRAAG_ID = @VRAAG_ID AND
			VRAAGONDERDEELNUMMER = @VRAAGONDERDEELNUMMER
			)
			THROW 50402, 'Dit vraagonderdeelnummer bestaat al', 1; 
		--Als Vraagonderdeelnummer NIET 1 is �n er geen vraagnummer bestaat dat gelijk is aan het ingevoerde vraagnummer - 1 dan...
		IF @VRAAGONDERDEELNUMMER > 1
		BEGIN
			IF NOT EXISTS (
				SELECT '' 
				FROM VRAAGONDERDEEL
				WHERE (@VRAAGONDERDEELNUMMER - 1) IN (
					SELECT VRAAGONDERDEELNUMMER
					FROM VRAAGONDERDEEL
					WHERE VRAAG_ID = @VRAAG_ID
					)
				)
				THROW 50401, 'Vraagonderdeelnummer dient te beginnen bij 1 en te worden opgehoogt met 1 voor ieder volgend vraagonderdeel.', 1;
		END
		IF @VRAAGSOORT != 'G' AND @VRAAGSOORT != 'O'
			THROW 50403, 'Vraagsoort kan alleen open of gesloten zijn', 1;
		ELSE
		--succes operatie hier
			INSERT INTO VRAAGONDERDEEL(VRAAG_ID, VRAAGONDERDEELNUMMER, VRAAGONDERDEEL, VRAAGSOORT)
			VALUES (@VRAAG_ID, @VRAAGONDERDEELNUMMER, @VRAAGONDERDEEL, @VRAAGSOORT)

		--als flow tot dit punt komt transactie counter met 1 verlagen
		COMMIT TRANSACTION 
	END TRY	  
	BEGIN CATCH
		IF XACT_STATE() = -1 and @startTrancount = 0  -- "doomed" transaction, eigen context only
			BEGIN
				ROLLBACK TRANSACTION
				PRINT 'Buitentran state -1 eigen context'
			END
		ELSE IF XACT_STATE() = 1 --transactie dus niet doomed, maar wel in error state 						 --je zit immers niet voor nop in het CATCH blok
			BEGIN
				ROLLBACK TRANSACTION @savepoint --werk van deze sproc ongedaan gemaakt
				COMMIT TRANSACTION --trancount 1 omlaag
				PRINT 'Buitentran state 1 met trancount ' + cast(@startTrancount as varchar)
			END
			DECLARE @errormessage varchar(2000) 
			SET @errormessage ='Een fout is opgetreden in procedure ''' + object_name(@@procid) + '''.
			Originele boodschap: ''' + ERROR_MESSAGE() + ''''
			RAISERROR(@errormessage, 16, 1) --of throw gebruiken, dat kan ook 
	END CATCH
END;	
GO