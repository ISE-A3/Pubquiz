USE BANG;
GO

CREATE or ALTER PROCEDURE dbo.usp_Antwoord_Insert
	@VRAAG_NAAM VARCHAR(256),
	@VRAAGONDERDEELNUMMER INT,
	@ANTWOORD VARCHAR(256),
	@PUNTEN INT
AS
BEGIN  
	DECLARE @savepoint varchar(128) = CAST(OBJECT_NAME(@@PROCID) as varchar(125)) + CAST(@@NESTLEVEL AS varchar(3))
	DECLARE @startTrancount int = @@TRANCOUNT;
	BEGIN TRY
		BEGIN TRANSACTION
		SAVE TRANSACTION @savepoint
		
		--checks hier
		IF NOT EXISTS (
			SELECT ''
			FROM VRAAGONDERDEEL VO
			WHERE VO.VRAAGONDERDEELNUMMER = @VRAAGONDERDEELNUMMER
			AND VO.VRAAG_ID = (
				SELECT V.VRAAG_ID
				FROM VRAAG V
				WHERE V.VRAAG_NAAM = @VRAAG_NAAM
				)
			)
			THROW 50003, 'Dit vraagonderdeel bestaat niet', 1
		IF @PUNTEN < 0
			THROW 50004, 'Punten kunnen niet lager zijn dan nul(0)', 1
		ELSE

		--succes operatie hier
		INSERT INTO ANTWOORD (VRAAGONDERDEEL_ID, ANTWOORD, PUNTEN)
		VALUES ((
			SELECT VRAAGONDERDEEL_ID
			FROM VRAAGONDERDEEL
			WHERE VRAAGONDERDEELNUMMER = @VRAAGONDERDEELNUMMER
			AND VRAAG_ID = (
				SELECT VRAAG_ID
				FROM VRAAG
				WHERE VRAAG_NAAM = @VRAAG_NAAM
				)
			), @ANTWOORD, @PUNTEN)


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