namespace :deploy do
  desc 'Deploy the app'
  task :production do
    app = "stranger-tides"
    remote = "git@heroku.com:#{app}.git"

    system "heroku maintenance:on --app #{app}"
    system "git push #{remote} master"
    system "heroku run rake db:migrate --app #{app}"
    system "heroku restart --app #{app}"
    system "heroku rake station_list:delete_station_list"
    system "heroku rake station_list:process_station_list"
    system "heroku rake station_list:try_this"

    system "heroku maintenance:off --app #{app}"
  end
end