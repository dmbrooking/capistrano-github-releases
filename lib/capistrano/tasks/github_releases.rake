require 'octokit'
require 'dotenv'
require 'highline'

Dotenv.load

module Dotenv
  def self.add(key_value, filename = nil)
    filename = File.expand_path(filename || '.env')
    f = File.open(filename, File.exists?(filename) ? 'a' : 'w')
    f.puts key_value
    key, value = key_value.split('=')
    ENV[key] = value
  end
end

namespace :github do
  namespace :releases do
    set :ask_release, false
    set :released_at, -> { Time.now }
    set :release_tag, -> { fetch(:released_at).strftime('%Y%m%d-%H%M%S%z') }
    set :release_title, -> { fetch(:released_at).strftime('%Y%m%d-%H%M%S%z') }
    set :release_body, -> { Octokit::Client.new.commits(fetch(:github_repo, 'deploy')).first.commit.message }

    set :username, -> {
      username = `git config --get user.name`.strip
      username = `whoami`.strip unless username
      username
    }

    set :github_token, -> {
      if ENV['GITHUB_PERSONAL_ACCESS_TOKEN'].nil?
        token = HighLine.new.ask('GitHub Personal Access Token?')
        Dotenv.add "GITHUB_PERSONAL_ACCESS_TOKEN=#{token}"
      else
        ENV['GITHUB_PERSONAL_ACCESS_TOKEN']
      end
    }

    set :github_repo, -> {
      repo = "#{fetch(:repo_url)}"
      repo.match(/([\w\-]+\/[\w\-\.]+)\.git$/)[1]
    }

    set :github_releases_path, -> {
      "#{Octokit.web_endpoint}#{fetch(:github_repo)}/releases/tag"
    }

    desc 'GitHub authentication'
    task :authentication do
      run_locally do
        begin
          Octokit.configure do |c|
            c.access_token = fetch(:github_token)
          end

          rate_limit = Octokit.rate_limit!
          info 'Exceeded limit of the GitHub API request' if rate_limit.remaining.zero?
          debug "#{rate_limit}"
        rescue Octokit::NotFound
          # No rate limit for white listed users
        rescue => e
          error e.message
        end
      end
    end

    desc 'Create new release note'
    task create: :authentication do
      run_locally do
        begin
          Octokit.create_release(
            fetch(:github_repo),
            fetch(:release_tag),
            name: fetch(:release_title),
            body: fetch(:release_body),
            target_commitish: 'master',
            draft: false,
            prerelease: false
          )
          info "Release as #{fetch(:release_tag)} to #{fetch(:github_repo)} was created"
        rescue => e
          error e.message
        end
      end
    end
  end
end
