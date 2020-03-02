create or replace procedure JOB_LOADER_DATA
is
  --- для открытия файла ---
  vfile         utl_file.file_type; 
  --- буфер ---
  vbuffer       varchar2(4000);     
  --- значение каждой колонки ---
  vcolumn       varchar2(4000);      
  --- текущая команда ---
  vcmd          varchar2(32767);    
  --- имя файла ---
  filename      varchar2(255);      
  --- имя таблицы ---
  tablename     varchar2(120);      
  --- первая строка с названием колонок ---
  vfirstrow     varchar2(4000);     
  --- признак сущ или нет таблица ---
  istableexists number := 0;        
  --- для формирования имени темповой таблицы ---
  vtmpprefix    varchar2(50) := '_tmp_' || replace(to_char(trunc(sysdate), 'YYYY.MM.DD'), '.','_');
  --- для логирования всех действий  ---
  vlog          varchar2(32767); 
  --- максимальное кол-во колонок, которое может обработать данная процедура ---  
  max_column_count number := 50;
  --- перечислитель строк, для подсчета кол-ва обработанных строк файла
  rowcounter       number := 0;
  --- расширенный лог ---
  v_ext_log        dbms_sql.varchar2a;
begin
  for rec in (select * from loader_tables where priz = 1)
  loop 
begin     
  filename  := rec.table_name || '.csv';
  tablename := rec.owner || '.' || substr(regexp_substr(filename, '[^.]+', 1, 1), 1, 120);
  dbms_output.put_line('--- **** ---');
  dbms_output.put_line(filename);
  dbms_output.put_line(tablename);
  dbms_output.put_line('--- **** ---');
  vlog     := vlog || '--- **** ---' || chr(13) || chr(10);
  vlog     := vlog || to_char(sysdate, 'hh24:mi:ss dd.mm.yyyy') || chr(13) || chr(10);
  vlog     := vlog || ': fileopen: ' || filename || chr(13) || chr(10);
  vlog     := vlog || chr(13) || chr(10);
  vfile    := utl_file.fopen('FOREX_EXPERT', filename, 'R');
  
  IF utl_file.is_open(vfile) THEN    
    vlog     := vlog || to_char(sysdate, 'hh24:mi:ss dd.mm.yyyy') || chr(13) || chr(10);
    vlog     := vlog || ': get_line: '; 
    vlog     := vlog || chr(13) || chr(10);
    -- Считываем первую строку с названием колонок
    utl_file.get_line(vfile, vbuffer);
    vfirstrow := vbuffer;
    vlog      := vlog || vbuffer;
    vlog      := vlog || chr(13) || chr(10);
    -- Необходимо определить создана таблица или нет
    declare
      v_rowid     rowid;
    begin
      vcmd := 'select MAX(rowid) from ' || tablename || ' where rownum = 1'; 
      execute immediate vcmd INTO v_rowid;
      istableexists := 1;
    exception
      when others then
        vlog := vlog || chr(13) || chr(10) ||  substr(sqlerrm, 1, 255);
        istableexists := 0;
    end;
    vlog := vlog || chr(13) || chr(10) ||  'tablename: ' || tablename;
    vlog := vlog || chr(13) || chr(10) ||  'istableexists: ' || istableexists;
    
    if istableexists = 0 -- если не создана то создаем
    then
      vcmd := 'create table ' || tablename || '(';
      for i in 1..max_column_count
      loop
        vcolumn := regexp_substr(vbuffer, '[^;]+', 1, i);
        if vcolumn is null
        then
          exit;
        end if;
        dbms_output.put_line(vcolumn);
        if i > 1 then vcmd := vcmd || ','; end if;
        vcmd := vcmd || UPPER(vcolumn) || ' varchar2(255)';
      end loop;
      vcmd := vcmd || ')';
      vlog := vlog || chr(13) || chr(10) || vcmd;
      execute immediate vcmd;
    end if; -- конец проверки опр необх создания таблицы
    istableexists := 0;
    vlog := vlog || chr(13) || chr(10) || 'tablename: ' || tablename || vtmpprefix;
   -- Необходимо определить создана темповая таблица или нет
    declare
      v_cnt    number;
    begin
      vcmd := 'select count(*) from ' || tablename || vtmpprefix; 
      vlog := vlog || chr(13) || chr(10) || vcmd;
      execute immediate vcmd INTO v_cnt;
      istableexists := 1;
    exception
      when others then
        if SQLCODE != -942 then
          vlog := vlog || chr(13) || chr(10) || substr(sqlerrm, 1, 255);          
        end if;  
        istableexists := 0;
    end;
   
   vlog := vlog || chr(13) || chr(10) ||  'istableexists: ' || istableexists;
      
   if istableexists = 0 -- если не создана то создаем
    then
      vcmd := 'create table ' || tablename || vtmpprefix || '(';      
      for i in 1..20
      loop
        vcolumn := regexp_substr(vbuffer, '[^;]+', 1, i);
        if vcolumn is null
        then
          exit;
        end if;
        if i > 1 then vcmd := vcmd || ','; end if;
        vcmd := vcmd || UPPER(vcolumn) || ' varchar2(255)';
      end loop;
      vcmd := vcmd || ')';
      vlog := vlog || chr(13) || chr(10) || vcmd;
      execute immediate vcmd;
    end if; -- конец проверки опр необх создания таблицы

   -- удаляем все из темповой таблицы
   vcmd := 'delete from ' || tablename || vtmpprefix;
   vlog := vlog || chr(13) || chr(10) || vcmd;
   execute immediate vcmd;    
    --
    v_ext_log(v_ext_log.count + 1) := vlog;   
    --
    LOOP
      BEGIN
        -- чтение всех строк файла 
        utl_file.get_line(vfile, vbuffer);
        IF vbuffer IS NULL THEN
          EXIT;
        END IF;
      -- обработка тек строки файла и составление комманды на добавление записи:
      vcmd := 'INSERT INTO ' || tablename || vtmpprefix || ' ( ';
      for j in 1..max_column_count
      loop
        vcolumn := regexp_substr(vfirstrow, '[^;]+', 1, j);
        if vcolumn is null
        then
          exit;
        end if;
        if j > 1 then vcmd := vcmd || ','; end if;
       vcmd := vcmd  || vcolumn;
      end loop;
      vcmd := vcmd || ') VALUES (';
      for j in 1..max_column_count
      loop
        vcolumn := regexp_substr(vbuffer, '[^;]+', 1, j);
        if vcolumn is null
        then
          exit;
        end if;
        if j > 1 then vcmd := vcmd || ','; end if;
       vcmd := vcmd  || chr(39) || vcolumn || chr(39);
      end loop;
      vcmd      := vcmd || ')';   
      v_ext_log(v_ext_log.count+1) := vcmd;
            
      execute immediate vcmd;
      rowcounter := rowcounter + 1;
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          EXIT;
      END;
    END LOOP;    
    vlog      := 'load_row: ' || rowcounter;
    vlog      := vlog || chr(13) || chr(10);
    vlog      := vlog || chr(13) || chr(10) || 'merge: ';
    -- Теперь из темповой переписываем в рабочую только те записи которых там нет
    vcmd := 
    'insert into ' || tablename ||
    '  select * from ' || tablename || vtmpprefix || ' t' ||
    ' where not exists(select 1 ' || 
    '                    from ' || tablename || ' a ' ||
    '                   where 1=1 '; 
    for j in 1..max_column_count
    loop
        vcolumn := regexp_substr(vfirstrow, '[^;]+', 1, j);
        if vcolumn is null
        then
          exit;
        end if;
       
      vcmd := vcmd || ' and a.' || vcolumn || ' = t.' || vcolumn;
    end loop;    
    vcmd := vcmd || ' )';
    execute immediate vcmd;        
    vlog := vlog || chr(13) || chr(10) || vcmd;
    vlog := vlog || chr(13) || chr(10) || 'rowcount: ' || sql%rowcount;
    -- удаление темповой таблицы
    begin
      vcmd := 'drop table ' || tablename || vtmpprefix;
      vlog := vlog || chr(13) || chr(10) || vcmd;
      execute immediate vcmd;
    exception
      when others then
        vlog := vlog || chr(13) || chr(10) || substr(sqlerrm, 1, 255);        
    end;
    -- фиксируем транзакцию
    COMMIT;    
    -- закрываем файл
    utl_file.fclose(vfile);      
    vlog := vlog || chr(13) || chr(10) || 'fileclose:' || filename;  
    -- удаляем файл      
    vlog := vlog || chr(13) || chr(10) || 'removefile:' || filename;        
    utl_file.fremove('FOREX_EXPERT', filename);
    vlog := vlog || chr(13) || chr(10) || '--- **** ---'|| chr(13) || chr(10);
  END IF;
      
  if vlog is not null then
  --- запишем лог, это важно:
  vfile := utl_file.fopen('FOREX_EXPERT', 'log.txt', 'A');
  begin
    for i in 1..v_ext_log.count 
    loop
      utl_file.put_line(vfile, v_ext_log(i));
    end loop;  
  exception
    when others then
      vlog := vlog || chr(13) || chr(10) || substr(sqlerrm, 1, 255) || chr(13) || chr(10);
  end;    
  utl_file.put_line(vfile, vlog);
  utl_file.fclose(vfile);
  ---
  end if;
exception
  when utl_file.invalid_operation then
    null;
  when others then
    ROLLBACK;    
    begin
    -- Закроем файл если он открыт
    IF utl_file.is_open(vfile) THEN      
      utl_file.fclose(vfile);
      vlog := vlog || chr(13) || chr(10) || to_char(sysdate, 'hh24:mi:ss dd.mm.yyyy');
      vlog := vlog || chr(13) || chr(10) || ':fileclose:' || filename || chr(13) || chr(10);
    end if;  
    exception
      when others then
        vlog := vlog || chr(13) || chr(10) || substr(sqlerrm, 1, 255) || chr(13) || chr(10);
    end;  
    vlog := vlog || chr(13) || chr(10) || 'load_row: ' || rowcounter;
    vlog := vlog || chr(13) || chr(10) || substr(sqlerrm, 1, 255) || chr(13) || chr(10);
    vlog := vlog || '--- **** ---' || chr(13) || chr(10);
    --- запишем лог, это важно:
    vfile := utl_file.fopen('FOREX_EXPERT', 'log.txt', 'A');
    for i in 1..v_ext_log.count 
    loop
      utl_file.put_line(vfile, v_ext_log(i));
    end loop;
    utl_file.put_line(vfile, vlog);
    utl_file.fclose(vfile);    
end;
end loop;
end;
/
