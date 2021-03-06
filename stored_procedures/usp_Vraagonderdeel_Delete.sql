USE BANG;
GO

/*
DELETE VRAAGONDERDEEL
*/

CREATE or ALTER PROCEDURE dbo.usp_Vraagonderdeel_Delete
	@VRAAG_NAAM VARCHAR(256),
	@VRAAGONDERDEELNUMMER INT = NULL
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
			FROM VRAAG
			WHERE VRAAG_NAAM = @VRAAG_NAAM
			)
			THROW 50006, 'Deze vraag bestaat niet', 1

		IF @VRAAGONDERDEELNUMMER IS NOT NULL BEGIN
			IF NOT EXISTS (
				SELECT ''
				FROM VRAAGONDERDEEL
				WHERE VRAAGONDERDEELNUMMER = @VRAAGONDERDEELNUMMER
				AND VRAAG_ID = (
					SELECT VRAAG_ID
					FROM VRAAG
					WHERE VRAAG_NAAM = @VRAAG_NAAM
					)
				)
				THROW 50001, 'Dit vraagonderdeel bestaat niet', 1
		END

		IF @VRAAGONDERDEELNUMMER IS NULL BEGIN
			IF NOT EXISTS (
				SELECT ''
				FROM VRAAGONDERDEEL
				WHERE VRAAG_ID = (
					SELECT VRAAG_ID
					FROM VRAAG
					WHERE VRAAG_NAAM = @VRAAG_NAAM
					)
				)
				THROW 50007, 'Er bestaan geen vraagonderdelen bij deze vraag', 1
		END

		--succes operatie hier
		IF @VRAAGONDERDEELNUMMER IS NOT NULL BEGIN
			IF EXISTS (
				SELECT ''
				FROM ANTWOORD
				WHERE VRAAGONDERDEEL_ID = (
					SELECT VRAAGONDERDEEL_ID
					FROM VRAAGONDERDEEL
					WHERE VRAAGONDERDEELNUMMER = @VRAAGONDERDEELNUMMER
					AND VRAAG_ID = (
						SELECT VRAAG_ID
						FROM VRAAG
						WHERE VRAAG_NAAM = @VRAAG_NAAM
						)
					)
				)
				EXECUTE dbo.usp_EenOfAlleAntwoordenVanVraagonderdeel_Delete @VRAAG_NAAM = @VRAAG_NAAM, @VRAAGONDERDEELNUMMER = @VRAAGONDERDEELNUMMER
				
				DELETE FROM VRAAGONDERDEEL
				WHERE VRAAGONDERDEELNUMMER = @VRAAGONDERDEELNUMMER
				AND VRAAG_ID = (
					SELECT VRAAG_ID
					FROM VRAAG
					WHERE VRAAG_NAAM = @VRAAG_NAAM
					)
		END

		IF @VRAAGONDERDEELNUMMER IS NULL BEGIN
			IF EXISTS (
				SELECT ''
				FROM ANTWOORD
				WHERE VRAAGONDERDEEL_ID IN (
					SELECT VRAAGONDERDEEL_ID
					FROM VRAAGONDERDEEL
					WHERE VRAAG_ID = (
						SELECT VRAAG_ID
						FROM VRAAG
						WHERE VRAAG_NAAM = @VRAAG_NAAM
						)
					)
				)
				EXECUTE dbo.usp_AlleAntwoordenVanAlleVraagonderdelenVanVraag_Delete @VRAAG_NAAM = @VRAAG_NAAM

				DELETE FROM VRAAGONDERDEEL
				WHERE VRAAG_ID = (
					SELECT VRAAG_ID
					FROM VRAAG
					WHERE VRAAG_NAAM = @VRAAG_NAAM
					)
		END

		EXEC dbo.usp_Afbeelding_Delete
		EXEC dbo.usp_Audio_Delete

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
