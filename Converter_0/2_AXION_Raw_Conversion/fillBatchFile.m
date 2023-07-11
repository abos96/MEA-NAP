function fillBatchFile (dirname,metadatafile,fill_div,fill_genotype,genotype,ExportFolder)
% fillBatchFile create a .csv file in the folder ExportFolder based on file in the dirname folder   
% edited by AB may23; 


    cd(ExportFolder)
    mat_files=dir('*.mat'); %pick out only .mat files produced by rawConvert.m
    batch_file=fullfile(dirname,metadatafile); 
    batchHdrs={'Filename','DIV','Genotype','Ground'}; 
    row_number=1;
    div_str='';

    batch_cell=cell(length(mat_files),length(batchHdrs));
    batch_table=cell2table(batch_cell,'VariableNames',batchHdrs);

    for i=1:length(mat_files)
        mat_fname=mat_files(i).name(1:end-4);
        batch_table.Filename{row_number}=mat_fname;

        if strcmp(fill_genotype,'y') 
            batch_table.Genotype(:,1)={genotype};
        end

        if strcmp(fill_div,'y')
            ii=strfind(mat_fname,'DIV')+3;

            while isstrprop(mat_fname(ii),'digit')
                div_str=append(div_str,mat_fname(ii));
                ii=ii+1;
            end 
            batch_table.DIV{row_number}=div_str;
            row_number=row_number+1;
            div_str='';
        end
    end
%     cell_batch = cell(1,size(batch_table,2));
      cell_batch = [{'Recording filename','DIV group','Genotype',''};(batch_table{:,:})]
      writecell((cell_batch),strcat(batch_file,'.csv'))
end
