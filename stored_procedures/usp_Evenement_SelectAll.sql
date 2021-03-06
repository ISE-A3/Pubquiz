use BANG
go

/*
SELECT ALL
*/

CREATE or ALTER PROCEDURE dbo.usp_Evenement_SelectAll
AS
BEGIN  
	DECLARE @savepoint varchar(128) = CAST(OBJECT_NAME(@@PROCID) as varchar(125)) + CAST(@@NESTLEVEL AS varchar(3))
	DECLARE @startTrancount int = @@TRANCOUNT;
	BEGIN TRY
		BEGIN TRANSACTION
		SAVE TRANSACTION @savepoint
		
		SELECT E.EVENEMENT_ID, E.EVENEMENT_NAAM, E.EVENEMENT_DATUM, L.LOCATIENAAM, T.STARTDATUM, T.EINDDATUM 
		FROM EVENEMENT E LEFT JOIN TOP100 T 
		ON E.EVENEMENT_ID = T.EVENEMENT_ID
		INNER JOIN LOCATIE L
		ON E.PLAATSNAAM = L.PLAATSNAAM AND E.ADRES = L.ADRES AND E.HUISNUMMER = L.HUISNUMMER AND E.HUISNUMMER_TOEVOEGING = L.HUISNUMMER_TOEVOEGING;

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