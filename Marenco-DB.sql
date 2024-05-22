CREATE DATABASE IF NOT EXISTS sat;
USE sat;

CREATE TABLE Ente_spaziale
(
    nome VARCHAR(100) PRIMARY KEY
);

CREATE TABLE IF NOT EXISTS Sede
(
    città     VARCHAR(100),
    CAP       VARCHAR(100) NOT NULL,
    via       VARCHAR(100) NOT NULL,
    nome_ente VARCHAR(100),
    PRIMARY KEY (città, nome_ente),
    FOREIGN KEY (nome_ente) REFERENCES Ente_spaziale (nome)
);

CREATE TABLE IF NOT EXISTS Satellite
(
    id                 INT AUTO_INCREMENT PRIMARY KEY,
    stato              VARCHAR(20) DEFAULT 'listen' CHECK ( stato IN ('working', 'listen')),
    data_lancio        DATE        NOT NULL,
    anno_fine_servizio DATE        NOT NULL,
    nome_ente          VARCHAR(100),
    FOREIGN KEY (nome_ente) REFERENCES Ente_spaziale (nome)
);

CREATE TABLE IF NOT EXISTS Dati_tecnici
(
    id_satellite INT PRIMARY KEY,
    peso         DECIMAL(10, 2) NOT NULL,
    propulsori   INT            NOT NULL,
    orbita       VARCHAR(30)    NOT NULL CHECK ( orbita IN ('LEO - Low Earth Orbit', 'MEO - Medium Earth Orbit',
                                                            'GEO - Geostationary Orbit',
                                                            'HEO - Highly Elliptical Orbit')),
    dimensione   INT            NOT NULL,
    FOREIGN KEY (id_satellite) REFERENCES Satellite (id)
);

CREATE TABLE IF NOT EXISTS Missione
(
    codice       INT AUTO_INCREMENT PRIMARY KEY,
    data_inizio  DATE         NOT NULL,
    data_fine    DATE         NOT NULL,
    stato        VARCHAR(20)  NOT NULL CHECK ( stato IN ('active', 'finished')),
    scopo        VARCHAR(255) NOT NULL,
    id_satellite INT,
    FOREIGN KEY (id_satellite) REFERENCES Satellite (id)
);

CREATE TABLE IF NOT EXISTS Dato
(
    id_dato         INT AUTO_INCREMENT PRIMARY KEY,
    dato            TEXT      NOT NULL,
    data_inizio     TIMESTAMP NOT NULL,
    codice_missione INT,
    FOREIGN KEY (codice_missione) REFERENCES Missione (codice)
);

CREATE TABLE IF NOT EXISTS Posizione
(
    titolo    VARCHAR(50),
    livello   INT,
    stipendio DECIMAL(10, 2) NOT NULL,
    PRIMARY KEY ( titolo, livello)
);

CREATE TABLE IF NOT EXISTS Dipendente
(
    CF        CHAR(16) PRIMARY KEY,
    titolo    VARCHAR(50),
    livello   INT,
    nome      VARCHAR(50)  NOT NULL,
    cognome   VARCHAR(50)  NOT NULL,
    qualifica VARCHAR(50)  NOT NULL,
    mail      VARCHAR(100) NOT NULL,
    FOREIGN KEY (titolo, livello) REFERENCES Posizione (titolo, livello)
);


CREATE TABLE IF NOT EXISTS Progetto
(
    etichetta  VARCHAR(100) PRIMARY KEY,
    specifiche TEXT           NOT NULL,
    budget     DECIMAL(15, 2) NOT NULL,
    attuazione INT          NOT NULL,
    nome_ente  VARCHAR(100),
    FOREIGN KEY (nome_ente) REFERENCES Ente_spaziale (nome)
);


CREATE TABLE IF NOT EXISTS Impiego
(
    CF           CHAR(16),
    nome_ente    VARCHAR(100),
    data_impiego DATE NOT NULL,
    PRIMARY KEY (CF, nome_ente),
    FOREIGN KEY (CF) REFERENCES Dipendente (CF),
    FOREIGN KEY (nome_ente) REFERENCES Ente_spaziale (nome)
);

-- STORED PROCEDURE ----------------------------------------------------------------------------------------------------

-- Sp 1 --> Visualizzare tutti i satelliti che hanno preso in carico una missione (stato = working).
DELIMITER $$

CREATE PROCEDURE ViewWorksSatellites()
BEGIN
    SELECT * FROM Satellite WHERE stato = 'working';
END $$
DELIMITER ;

-- Sp 2 --> Ottenere la lista delle missioni attualmente in corso.
DELIMITER $$

CREATE PROCEDURE MissionsActiveList()
BEGIN
    SELECT * FROM Missione WHERE stato = 'active' ORDER BY data_fine;
END $$
DELIMITER ;

-- Sp 3 --> Elenco dei satelliti che hanno terminato il loro servizio.
DELIMITER $$

CREATE PROCEDURE FinishedSatellites()
BEGIN
    SELECT * FROM Satellite WHERE anno_fine_servizio < CURRENT_DATE();
END $$
DELIMITER ;

-- Sp 4 --> Ottenere il budget totale dei progetti di un ente per un anno specifico.

DELIMITER $$

CREATE PROCEDURE BudgetTotale(IN ente VARCHAR(100), IN anno INT)
BEGIN
    SELECT SUM(budget) as BudgetTotale
    FROM Progetto
    WHERE nome_ente = ente
      AND attuazione = anno;
END $$
DELIMITER ;

-- Sp 5 --> Eseguire il calcolo degli stipendi mensili per tutti i dipendenti.

DELIMITER $$

CREATE PROCEDURE TotalSalary()
BEGIN
    SELECT i.nome_ente, SUM(p.stipendio) AS TotaleStipendiMensili
    FROM Dipendente d
             LEFT JOIN Posizione p USING (titolo, livello)
             LEFT JOIN Impiego i USING (CF)
    GROUP BY i.nome_ente;

END $$
DELIMITER ;

-- Sp 6 --> Aggiornamento dello stato dei satelliti

DELIMITER $$

CREATE PROCEDURE UpdateStateSatellite()
BEGIN

    -- Aggiorna lo stato della missione a 'finished' se la missione è terminata

    UPDATE Missione
    SET stato = 'finished'
    WHERE data_fine < CURRENT_DATE()
      AND stato != 'finished';

    -- Setta lo stato del satellite a 'listen' se non è coinvolto in una missione attiva
    
    UPDATE Satellite s
    SET s.stato = 'listen'
    WHERE s.id NOT IN (
        SELECT m.id_satellite
        FROM Missione m
        WHERE m.stato != 'finished'
    );

END $$
DELIMITER ;


-- VISTE ---------------------------------------------------------------------------------------------------------------

-- Tr 1 -->  Controllare lo stato dei satelliti e la data di fine servizio prima di aggiornare missione

DELIMITER  $$
CREATE TRIGGER CheckMissionSatellite
    BEFORE INSERT
    ON Missione
    FOR EACH ROW
BEGIN
    DECLARE stato_satellite varchar(20);
    DECLARE fine_servizio DATE;
    SELECT stato INTO stato_satellite FROM Satellite WHERE id = NEW.id_satellite;
    SELECT anno_fine_servizio INTO fine_servizio FROM Satellite WHERE id = NEW.id_satellite;
    IF stato_satellite = 'working' THEN
        SIGNAL sqlstate '45001' SET message_text =
                "Impossibile assegnare missione, il satellite è gia occupato in un'altra missione";
    END IF;

    IF NEW.data_fine > fine_servizio THEN
        SIGNAL sqlstate '45001' SET message_text =
                "Impossibile assegnare missione, il satellite verrà dismesso prima di poter concludere la missione";
    END IF;

    UPDATE Satellite s
    SET s.stato = 'working'
    WHERE id = NEW.id_satellite;

END $$
DELIMITER ;

-- Tr 2 -->  Controllo numero massimo satelliti per ente spaziale

DELIMITER $$

CREATE TRIGGER CheckMaxSatellitiNumber
    BEFORE INSERT
    ON Satellite
    FOR EACH ROW
BEGIN
    DECLARE numero_satelliti INT;
    SELECT COUNT(*) INTO numero_satelliti FROM Satellite WHERE nome_ente = NEW.nome_ente;
    IF numero_satelliti > 100 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Superato il numero massimo di satelli per ente';
    END IF;
END $$
DELIMITER ;


-- Tr 3 -->  Controllare unicità delle sedi per città

DELIMITER $$

CREATE TRIGGER CheckUniqueLocation
    BEFORE INSERT
    ON Sede
    FOR EACH ROW
BEGIN
    DECLARE numero_sedi INT;
    SELECT COUNT(*) INTO numero_sedi FROM Sede WHERE città = NEW.città;
    IF numero_sedi > 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Esiste già una sede in questa città';
    END IF;
END $$
DELIMITER ;


-- POPOLAMENTO ---------------------------------------------------------------------------------------------------------

INSERT INTO Ente_spaziale (nome) VALUES
('NASA'),
('ESA'),
('JAXA'),
('Roscosmos'),
('ISRO');

INSERT INTO Sede (città, CAP, via, nome_ente) VALUES
('Washington', '20546', '300 E Street SW', 'NASA'),
('Houston', '77058', '2101 NASA Parkway', 'NASA'),
('Parigi', '75015', '24 Rue Edouard Vaillant', 'ESA'),
('Noordwijk', '2201', 'Keplerlaan 1', 'ESA'),
('Tokyo', '100-0005', 'Chiyoda-ku', 'JAXA'),
('Tsukuba', '305-8505', '2-1-1 Sengen', 'JAXA'),
('Mosca', '117997', '42, Schepkina Street', 'Roscosmos'),
('Korolev', '141070', 'Leninskaya ulitsa 4A', 'Roscosmos'),
('Bangalore', '560094', 'New BEL Road', 'ISRO'),
('Sriharikota', '524124', 'SHAR Road', 'ISRO');

INSERT INTO Satellite (stato, data_lancio, anno_fine_servizio, nome_ente) VALUES
('listen', '2020-01-15', '2030-01-15', 'NASA'),
('listen', '2015-06-30', '2025-06-30', 'NASA'),
('listen', '2018-03-12', '2028-03-12', 'ESA'),
('listen', '2019-11-23', '2029-11-23', 'ESA'),
('listen', '2017-08-10', '2027-08-10', 'JAXA'),
('listen', '2021-05-10', '2031-05-10', 'JAXA'),
('listen', '2016-10-30', '2026-10-30', 'Roscosmos'),
('listen', '2020-04-14', '2030-04-14', 'Roscosmos'),
('listen', '2019-01-25', '2029-01-25', 'ISRO'),
('listen', '2018-07-19', '2028-07-19', 'ISRO'),
('listen', '2010-02-13', '2020-08-09', 'NASA');

INSERT INTO Dati_tecnici (id_satellite, peso, propulsori, orbita, dimensione) VALUES
(1, 1500.50, 4, 'LEO - Low Earth Orbit', 10),
(2, 1200.75, 3, 'MEO - Medium Earth Orbit', 8),
(3, 1800.00, 5, 'GEO - Geostationary Orbit', 12),
(4, 2000.25, 6, 'HEO - Highly Elliptical Orbit', 15),
(5, 1300.50, 4, 'LEO - Low Earth Orbit', 9),
(6, 1450.80, 3, 'MEO - Medium Earth Orbit', 10),
(7, 1750.25, 5, 'GEO - Geostationary Orbit', 11),
(8, 1600.30, 4, 'HEO - Highly Elliptical Orbit', 13),
(9, 1550.75, 4, 'LEO - Low Earth Orbit', 12),
(10, 1700.50, 3, 'MEO - Medium Earth Orbit', 14);

INSERT INTO Missione (data_inizio, data_fine, stato, scopo, id_satellite) VALUES
('2020-02-01', '2023-02-01', 'finished', 'Earth observation', 1),
('2016-07-01', '2022-07-01', 'finished', 'Communication', 2),
('2018-04-01', '2023-04-01', 'finished', 'Scientific research', 3),
('2019-12-01', '2024-12-01', 'active', 'Weather monitoring', 4),
('2017-09-01', '2023-09-01', 'finished', 'Navigation', 5),
('2021-06-01', '2024-06-01', 'active', 'Resource mapping', 6),
('2017-11-01', '2022-11-01', 'finished', 'Military surveillance', 7),
('2020-05-01', '2025-05-01', 'active', 'Space debris tracking', 8),
('2019-02-01', '2024-02-01', 'finished', 'Climate monitoring', 9),
('2018-08-01', '2023-08-01', 'finished', 'Ocean monitoring', 10);

INSERT INTO Dato (dato, data_inizio, codice_missione) VALUES
('Temperature data', '2020-02-01 00:00:00', 1),
('Signal strength data', '2016-07-01 00:00:00', 2),
('Radiation levels', '2018-04-01 00:00:00', 3),
('Cloud cover data', '2019-12-01 00:00:00', 4),
('GPS coordinates', '2017-09-01 00:00:00', 5),
('Mineral composition', '2021-06-01 00:00:00', 6),
('Surveillance footage', '2017-11-01 00:00:00', 7),
('Debris location data', '2020-05-01 00:00:00', 8),
('Climate patterns', '2019-02-01 00:00:00', 9),
('Ocean salinity levels', '2018-08-01 00:00:00', 10);

INSERT INTO Posizione (titolo, livello, stipendio) VALUES
('Chief Engineer', 3, 75000.00),
('Lead Scientist', 2, 65000.00),
('Senior Technician', 1, 55000.00),
('Data Analyst', 1, 50000.00),
('Project Manager', 2, 70000.00),
('Junior Engineer', 1, 50000.00),
('Research Scientist', 2, 60000.00),
('Technician', 1, 45000.00),
('Senior Analyst', 2, 55000.00),
('Program Manager', 3, 75000.00);

INSERT INTO Dipendente (CF, titolo, livello, nome, cognome, qualifica, mail) VALUES
('RSSMRA80A01H501Z', 'Chief Engineer', 3, 'Mario', 'Rossi', 'Engineer', 'mario.rossi@nasa.gov'),
('BNCLRA85T50F205Z', 'Lead Scientist', 2, 'Laura', 'Bianchi', 'Scientist', 'laura.bianchi@esa.int'),
('VRDFRB90T12L219Z', 'Senior Technician', 1, 'Fabrizio', 'Verdi', 'Technician', 'fabrizio.verdi@jaxa.jp'),
('GRMBTT75A01H501Z', 'Data Analyst', 1, 'Bettina', 'Gromov', 'Analyst', 'bettina.gromov@roscosmos.ru'),
('PNTLRA82T11L382Z', 'Project Manager', 2, 'Lara', 'Pant', 'Manager', 'lara.pant@isro.in'),
('MNCLRA92T20F205Z', 'Junior Engineer', 1, 'Monica', 'Lari', 'Engineer', 'monica.lari@nasa.gov'),
('FRCDNL88S21L307Z', 'Research Scientist', 2, 'Daniela', 'Franchi', 'Scientist', 'daniela.franchi@esa.int'),
('GRCJLS89U15L341Z', 'Technician', 1, 'Julian', 'Grecchi', 'Technician', 'julian.grecchi@jaxa.jp'),
('SNGLKI75L01H501Z', 'Senior Analyst', 2, 'Li', 'Sang', 'Analyst', 'li.sang@roscosmos.ru'),
('KMTLRK80M11L552Z', 'Program Manager', 3, 'Raj', 'Kumar', 'Manager', 'raj.kumar@isro.in');


INSERT INTO Progetto (etichetta, specifiche, budget, attuazione, nome_ente) VALUES
('Artemis', 'Lunar exploration program', 3500000000.00, 2024, 'NASA'),
('Galileo', 'Satellite navigation system', 2000000000.00, 2022, 'ESA'),
('Hayabusa2', 'Asteroid sample return mission', 1500000000.00, 2023, 'JAXA'),
('Luna-25', 'Lunar lander mission', 500000000.00, 2021, 'Roscosmos'),
('Mangalyaan 2', 'Mars orbiter mission', 1000000000.00, 2025, 'ISRO'),
('JWST', 'James Webb Space Telescope', 10000000000.00, 2021, 'NASA'),
('ExoMars', 'Mars rover mission', 1200000000.00, 2022, 'ESA'),
('MMX', 'Martian Moons Exploration', 3000000000.00, 2024, 'JAXA'),
('Venera-D', 'Venus exploration mission', 700000000.00, 2023, 'Roscosmos'),
('Chandrayaan 3', 'Lunar lander mission', 900000000.00, 2024, 'ISRO');

INSERT INTO Impiego (CF, nome_ente, data_impiego) VALUES
('RSSMRA80A01H501Z', 'NASA', '2015-01-01'),
('BNCLRA85T50F205Z', 'ESA', '2016-03-15'),
('VRDFRB90T12L219Z', 'JAXA', '2018-06-01'),
('GRMBTT75A01H501Z', 'Roscosmos', '2019-11-23'),
('PNTLRA82T11L382Z', 'ISRO', '2020-08-10'),
('MNCLRA92T20F205Z', 'NASA', '2018-02-14'),
('FRCDNL88S21L307Z', 'ESA', '2017-04-21'),
('GRCJLS89U15L341Z', 'JAXA', '2019-09-10'),
('SNGLKI75L01H501Z', 'Roscosmos', '2020-11-30'),
('KMTLRK80M11L552Z', 'ISRO', '2021-07-25');

call UpdateStateSatellite();
