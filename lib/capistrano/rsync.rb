require File.expand_path("../rsync/version", __FILE__)

set_if_empty :rsync_options, [
  '--archive'
]
set_if_empty :rsync_copy, "rsync --archive --acls --xattrs"

# Sparse checkout allows to checkout only part of the repository
set_if_empty :rsync_sparse_checkout, []

# Merely here for backward compatibility reasons
set_if_empty :rsync_checkout_tag, false

# Option states what to checkout
set_if_empty :rsync_checkout, -> { fetch(:rsync_checkout_tag, false) ? "tag" : "branch"}

# You may not need the whole history, put to false to get it whole
set_if_empty :rsync_depth, 1

# Stage is used on your local machine for rsyncing from.
set_if_empty :rsync_stage, "tmp/deploy"

# Cache is used on the server to copy files to from to the release directory.
# Saves you rsyncing your whole app folder each time.  If you nil rsync_cache,
# Capistrano::Rsync will sync straight to the release path.
set_if_empty :rsync_cache, "shared/deploy"

set_if_empty :rsync_target_dir, "."

# Creates opportunity to define remote other than origin
set_if_empty :git_remote, "origin"

set_if_empty :enable_git_submodules, false

set_if_empty :reset_git_submodules_before_update, false

set_if_empty :bypass_git_clone, false

# NOTE: Please don't depend on tasks without a description (`desc`) as they
# might change between minor or patch version releases. They make up the
# private API and internals of Capistrano::Rsync. If you think something should
# be public for extending and hooking, please let me know!

rsync_cache = lambda do
  cache = fetch(:rsync_cache)
  cache = deploy_to + "/" + cache if cache && cache !~ /^\//
  cache
end

rsync_target = lambda do
  case fetch(:rsync_checkout)
    when "tag"
      target = "tags/#{fetch(:branch)}"
    when "revision"
      target = fetch(:branch)
    else
      target = [fetch(:git_remote), fetch(:branch).to_s].reject(&:blank?).join("/")
    end
  target
end

rsync_branch = lambda do
  if fetch(:rsync_checkout) == "tag"
    branch = "tags/#{fetch(:branch)}"
  else
    branch = fetch(:branch)
  end

  branch
end

git_depth = lambda do
  depth = !!fetch(:rsync_depth, false) ? "--depth=#{fetch(:rsync_depth)}" : ""
  depth
end

git_depth_clone = lambda do
  depth = !!fetch(:rsync_depth, false) ? "--depth=#{fetch(:rsync_depth)} --no-single-branch" : ""
  depth
end

Rake::Task["deploy:check"].enhance ["rsync:hook_scm"]

# Local -> Remote cache
desc "Stage and rsync to the server (or its cache)."
task :rsync => %w[rsync:stage_done] do
  release_roles(:all).each do |role|
    user = role.user + "@" if !role.user.nil?
    rsync_options = fetch(:rsync_options)

    if !role.port.nil?
      rsync_options.unshift("-e 'ssh -p #{role.port}'")
    end

    run_locally do
      within fetch(:rsync_stage) do
        execute :rsync,
            rsync_options,
            fetch(:rsync_target_dir),
            "#{user}#{role.hostname}:#{rsync_cache.call || release_path}"
      end
    end
  end
end

namespace :rsync do

  def has_roles?
    return env.filter(release_roles(:all)).any?
  end

  desc 'Locally determine the revision that will be deployed'
  task :set_current_revision do
    next if !has_roles?

    run_locally do
      within fetch(:rsync_stage) do
        rev = capture(:git, 'rev-parse', 'HEAD').strip
        set :current_revision, rev
      end
    end
  end

  task :hook_scm do
    Rake::Task.define_task("#{scm}:check") do
      invoke "rsync:check"
    end

    Rake::Task.define_task("#{scm}:create_release") do
      invoke "rsync:release"
    end
  end

  task :check do
    next if !fetch(:rsync_cache)
    next if !has_roles?

    on release_roles :all do
      execute :mkdir, '-pv', File.join("#{fetch(:deploy_to)}", "#{fetch(:rsync_cache)}")
    end
  end

  # Git first time -> Local
  task :create_stage do
    next if File.directory?(fetch(:rsync_stage))
    next if !has_roles?
    next if fetch(:bypass_git_clone)

    if fetch(:rsync_sparse_checkout, []).any?
      run_locally do
        execute :git, :init, '--quiet', fetch(:rsync_stage)
        within fetch(:rsync_stage) do
          execute :git, :remote, :add, :origin, fetch(:repo_url)

          execute :git, :fetch, '--quiet --prune --all -t', "#{git_depth.call}"

          execute :git, :config, 'core.sparsecheckout true'
          execute :mkdir, '.git/info'
          open(File.join(fetch(:rsync_stage), '.git/info/sparse-checkout'), 'a') { |f|
            fetch(:rsync_sparse_checkout).each do |sparse_dir|
              f.puts sparse_dir
            end
          }

          execute :git, :pull, '--quiet', "#{git_depth.call}", :origin, "#{rsync_branch.call}"
        end
      end
    else
      submodules = !!fetch(:enable_git_submodules) ? "--recursive" : ""
      run_locally do
        execute :git,
          :clone,
          '--quiet',
          fetch(:repo_url),
          fetch(:rsync_stage),
          "#{git_depth_clone.call}",
          "#{submodules}"
      end
    end
  end

  # Git update -> Local
  desc "Stage the repository in a local directory."
  task :stage => %w[create_stage] do
    next if !has_roles?
    next if fetch(:bypass_git_clone)

    run_locally do
      within fetch(:rsync_stage) do
        execute :git, :fetch, '--quiet --all --prune', "#{git_depth.call}"

        if !!fetch(:rsync_checkout_tag, false)
          execute :git, :fetch, '--quiet --tags'
        end

        execute :git, :reset, '--quiet', '--hard', "#{rsync_target.call}"

        if fetch(:enable_git_submodules)
          if fetch(:reset_git_submodules_before_update)
            execute :git, :submodule, :foreach, "'git reset --hard HEAD && git clean -qfd && git fetch -t'"
          end

          execute :git, :submodule, :update
        end
      end
    end
  end

  task :stage_done => %w[stage]

  # Remote Cache -> Remote Release
  desc "Copy the code to the releases directory."
  task :release => %w[rsync] do
    # Skip copying if we've already synced straight to the release directory.
    next if !fetch(:rsync_cache)
    next if !has_roles?

    copy = %(#{fetch(:rsync_copy)} "#{rsync_cache.call}/" "#{release_path}/")
    on release_roles(:all) do |host|
      execute copy
    end
  end

  # Matches the naming scheme of git tasks.
  # Plus was part of the public API in Capistrano::Rsync <= v0.2.1.
  task :create_release => %w[release]
end
