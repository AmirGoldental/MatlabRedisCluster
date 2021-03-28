function test()
test_result = runtests('mrc.test_class');
test_result_table = test_result.table();
disp(test_result_table(:,{'Name', 'Passed', 'Duration'}))
end