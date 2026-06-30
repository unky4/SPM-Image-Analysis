function createdir(path)
% Created dir if it does not exists
    if exist(path, 'dir') == 0
        mkdir(path);
    end
end