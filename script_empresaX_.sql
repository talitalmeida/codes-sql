--TRIGGERS E FUNÇÕES

--domínio para campo sexo
CREATE DOMAIN dm_sexo AS char(1)
DEFAULT 'M'
NOT NULL
CHECK (VALUE IN ('M', 'F'));

--domínio para campo nascimento
CREATE DOMAIN dm_nascimento AS date
DEFAULT '01/01/1900'
NOT NULL
CHECK ( VALUE > '01/01/1900');

--domínio para campo nome 
CREATE DOMAIN dm_nome AS varchar(50) 
NOT NULL;

--domínio para campo descricao 
CREATE DOMAIN dm_descricao AS varchar(100) 
NOT NULL;

--tipo enumeração
CREATE TYPE enum_situacao AS ENUM('ativa','suspensa','cancelada');

--criação das tabelas
CREATE TABLE cargos (
  codCargo integer NOT NULL,
  nome dm_nome,
  CONSTRAINT cargos_pk PRIMARY KEY (codCargo)
);

CREATE TABLE departamentos (
  codDepartamento integer NOT NULL,
  nome dm_nome,
  totalSalario numeric(10,2) default 0.0,
  qtdEmpregados integer default 0,
  CONSTRAINT departamentos_pk PRIMARY KEY (codDepartamento)
);

-- Q10
CREATE OR REPLACE FUNCTION atualiza_qtd_empregados_departamentos()
RETURNS TRIGGER AS $$
	BEGIN
		IF TG_OP = 'INSERT' THEN
			UPDATE departamentos
			SET qtdEmpregados = qtdEmpregados + 1
			WHERE codDepartamento = NEW.cod_departamento;
		ELSEIF TG_OP = 'DELETE' THEN
			UPDATE departamentos
			SET qtdEmpregados = qtdEmpregados - 1
			WHERE codDepartamento = OLD.cod_departamento;
		END IF;
		RETURN NEW;
	END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_atualiza_qtd_empDep
AFTER INSERT OR DELETE ON empregados
FOR EACH ROW
	EXECUTE PROCEDURE atualiza_qtd_empregados_departamentos();

-- Q9
CREATE OR REPLACE FUNCTION atualizaTotalSalarioDep()
RETURNS TRIGGER AS $$
	BEGIN
		IF TG_OP = 'INSERT' THEN
    		UPDATE departamentos
    		SET totalSalario = totalSalario + NEW.salario
    		WHERE codDepartamento = NEW.cod_departamento;
  		ELSIF TG_OP = 'UPDATE' THEN
    		UPDATE departamentos
    		SET totalSalario = (totalSalario - OLD.salario) + NEW.salario
    		WHERE codDepartamento = NEW.cod_departamento;
  		ELSIF TG_OP = 'DELETE' THEN
    		UPDATE departamentos
    		SET totalSalario = totalSalario - OLD.salario
    		WHERE codDepartamento = OLD.cod_departamento;
  		END IF;
  		RETURN NEW;
	END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_atualizaTotalSalarioDep
AFTER INSERT OR UPDATE OR DELETE ON empregados
FOR EACH ROW
	EXECUTE PROCEDURE atualizaTotalSalarioDep();

CREATE TABLE empregados (
  codEmpregado integer NOT NULL,
  primeiro_nome dm_nome,
  ultimo_nome dm_nome, 
  sexo dm_sexo, 
  cpf char(11),
  cod_cargo integer NOT NULL,
  data_nasc dm_nascimento,
  data_admissao date,  
  salario numeric(10,2),
  inss numeric(10,2),  
  cod_departamento integer NOT NULL,
  CONSTRAINT empregados_pk PRIMARY KEY (codEmpregado),
  CONSTRAINT empregados_cargos_fk FOREIGN KEY (cod_cargo) REFERENCES cargos(codCargo),
  CONSTRAINT empregados_departamentos_fk FOREIGN KEY (cod_departamento) REFERENCES departamentos (codDepartamento) 
);

-- Q6
CREATE OR REPLACE FUNCTION nome_departamento(idDepartamento int)
RETURNS dm_nome AS $$
	SELECT nome FROM departamentos WHERE codDepartamento = idDepartamento;	
$$ LANGUAGE SQL;

-- Q5
CREATE OR REPLACE FUNCTION nome_empregado(idEmpregado int)
RETURNS varchar AS $$
DECLARE
    nome_completo varchar(45);
BEGIN
    SELECT CONCAT_WS(' ', primeiro_nome, ultimo_nome) INTO nome_completo
    FROM empregados
    WHERE codEmpregado = idEmpregado;

    RETURN nome_completo;
END;
$$ LANGUAGE plpgsql;

-- Q4

CREATE OR REPLACE FUNCTION info_empregado(id_empregado int)
RETURNS empregados AS $$
	SELECT * FROM empregados WHERE codEmpregado = id_empregado;
$$ LANGUAGE SQL;


-- Q3
CREATE OR REPLACE FUNCTION valorTotal_inss(codDepartamento int)
RETURNS numeric(10,2) AS 
$$
	DECLARE
		total_inss numeric(10,2);
	BEGIN
		SELECT COALESCE(SUM(inss),0) INTO total_inss
		FROM empregados
		WHERE cod_departamento = codDepartamento;
		
		RETURN total_inss;
	END;
$$LANGUAGE plpgsql;


-- Q2
CREATE OR REPLACE FUNCTION validaCPF(cpf varchar(11))
RETURNS BOOLEAN AS 
$$
	DECLARE
    	cpf_numero integer[];
    	sum integer;
    	dv1 integer;
    	dv2 integer;
	BEGIN
    	cpf_numero := string_to_array(regexp_replace(cpf, '[^0-9]', '', 'g'), NULL);

	    IF array_length(cpf_numero, 1) <> 11 THEN
    	    RETURN FALSE;
    	END IF;

    	sum := 0;
    	FOR i IN 1..9 LOOP
        	sum := sum + cpf_numero[i] * (11 - i);
    	END LOOP;

    	dv1 := CASE WHEN (sum * 10) % 11 = 10 THEN 0 
			ELSE (sum * 10) % 11 END;

    	sum := 0;
    	FOR i IN 1..10 LOOP
        	sum := sum + cpf_numero[i] * (12 - i);
    	END LOOP;

    	dv2 := CASE WHEN (sum * 10) % 11 = 10 THEN 0 
			ELSE (sum * 10) % 11 END;

    	RETURN dv1 = cpf_numero[10] AND dv2 = cpf_numero[11];
	END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION verifica_cpf()
RETURNS TRIGGER AS
$$
	BEGIN
		IF NOT validaCPF(NEW.cpf) THEN
			RAISE EXCEPTION 'CPF inválido!';
		END IF;
		RETURN NEW;
	END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_verifica_cpf
BEFORE INSERT ON empregados
FOR EACH ROW 
	EXECUTE PROCEDURE verifica_cpf();
	
-- Q1
CREATE OR REPLACE FUNCTION calcula_inss()
RETURNS TRIGGER AS
$$
	BEGIN
		IF NEW.salario <= 2000 THEN
			NEW.inss = NEW.salario*0.1;
		ELSE
			NEW.inss = NEW.salario*0.15;
		END IF;
		RETURN NEW;
	END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_calcula_inss 
BEFORE INSERT OR UPDATE OF 
salario ON empregados FOR EACH ROW
	EXECUTE PROCEDURE calcula_inss();

--
CREATE TABLE obras (
  codObra integer NOT NULL,
  descricao varchar(50),
  cidade varchar(50) NOT NULL DEFAULT 'Santarém',
  data_inicio date,
  data_prevista_termino date,
  situacao enum_situacao NOT NULL,
  CONSTRAINT obras_pk PRIMARY KEY (codObra)
);

--Q7

CREATE OR REPLACE FUNCTION insere_empEspecifico()
RETURNS TRIGGER AS $$
	DECLARE
		cargo_nome varchar(45);
		status varchar(45);
	BEGIN
		SELECT INTO cargo_nome cargos.nome FROM empregados JOIN cargos
		ON empregados.codEmpregado = cargos.codCargo 
		WHERE empregados.codEmpregado = NEW.codEmpregado;
		
		SELECT INTO status obras.situacao FROM obras WHERE NEW.codObra = codObra;
		
		IF cargo_nome IN ('Pedreiro', 'Motorista', 'Operador de Máquina') AND status = 'ativa' THEN
			RETURN NEW;
		ELSE
			RAISE EXCEPTION 'Empregado ou Obra não qualificada!';
		END IF;
	END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_empEspecifico
BEFORE INSERT ON empregados_obras
FOR EACH ROW
	EXECUTE PROCEDURE insere_empEspecifico();
	
-- Q8
CREATE OR REPLACE FUNCTION verifica_data_admissao_empregado()
RETURNS TRIGGER AS $$
	BEGIN
		IF NEW.data_admissao < CURRENT_DATE THEN
			RAISE EXCEPTION 'Data de admissão incorreta!';
		END IF;
		RETURN NEW;
	END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER dataAdmissao_emp
BEFORE INSERT ON empregados
FOR EACH ROW
	EXECUTE PROCEDURE verifica_data_admissao_empregado();


--
CREATE TABLE empregados_obras (
  codObra integer NOT NULL,
  codEmpregado integer NOT NULL,
  data_alocacaoempregado date,
  CONSTRAINT empregados_obras_pk PRIMARY KEY (codObra, codEmpregado),
  CONSTRAINT empregados_obras_codObra_FK FOREIGN KEY (codObra) REFERENCES obras (codObra),
  CONSTRAINT empregados_obra_codEmpregado_FK FOREIGN KEY (codEmpregado) REFERENCES empregados (codEmpregado)
);