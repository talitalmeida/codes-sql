CREATE OR REPLACE FUNCTION validarCPF(cpf varchar(11))
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

SELECT validarCPF('1234.56789-09'); -- cpf válido
SELECT validarCPF('123,456.78910'); -- cpf inválido
