rsync_plugin = self
# Local -> Remote cache
desc 'Stage and rsync to the server (or its cache).'
task rsync: %w[rsync:stage_done] do
  release_roles(:all).each do |role|
    user = role.user + '@' unless role.user.nil?
    rsync_options = fetch(:rsync_options)

    rsync_options.unshift("-e 'ssh -p #{role.port}'") unless role.port.nil?

    run_locally do
      within fetch(:rsync_stage) do
        execute :rsync,
                rsync_options,
                fetch(:rsync_target_dir),
                "#{user}#{role.hostname}:#{rsync_plugin.rsync_cache || release_path}"
      end
    end
  end
end

namespace :rsync do
  def has_roles?
    env.filter(release_roles(:all)).any?
  end

  desc 'Locally determine the revision that will be deployed'
  task :set_current_revision do
    next unless has_roles?

    run_locally do
      within fetch(:rsync_stage) do
        rev = capture(:git, 'rev-parse', 'HEAD').strip
        set :current_revision, rev
      end
    end
  end

  task :check do
    next unless fetch(:rsync_cache)
    next unless has_roles?

    on release_roles :all do
      execute :mkdir, '-pv', File.join(fetch(:deploy_to).to_s, fetch(:rsync_cache).to_s)
    end
  end

  # Git first time -> Local
  task :create_stage do
    next if File.directory?(fetch(:rsync_stage))
    next unless has_roles?
    next if fetch(:bypass_git_clone)

    if fetch(:rsync_sparse_checkout, []).any?
      run_locally do
        execute :git, :init, '--quiet', fetch(:rsync_stage)
        within fetch(:rsync_stage) do
          execute :git, :remote, :add, :origin, fetch(:repo_url)

          execute :git, :fetch, '--quiet --prune --all -t', rsync_plugin.git_depth.to_s

          execute :git, :config, 'core.sparsecheckout true'
          execute :mkdir, '.git/info'
          open(File.join(fetch(:rsync_stage), '.git/info/sparse-checkout'), 'a') do |f|
            fetch(:rsync_sparse_checkout).each do |sparse_dir|
              f.puts sparse_dir
            end
          end

          execute :git, :pull, '--quiet', rsync_plugin.git_depth.to_s, :origin, rsync_plugin.rsync_branch.to_s
        end
      end
    else
      submodules = !!fetch(:enable_git_submodules) ? '--recursive' : ''
      run_locally do
        execute :git,
                :clone,
                '--quiet',
                fetch(:repo_url),
                fetch(:rsync_stage),
                rsync_plugin.git_depth_clone.to_s,
                submodules.to_s
      end
    end
  end

  # Git update -> Local
  desc 'Stage the repository in a local directory.'
  task stage_done: %w[create_stage] do
    next unless has_roles?
    next if fetch(:bypass_git_clone)

    run_locally do
      within fetch(:rsync_stage) do
        execute :git, :fetch, '--quiet --all --prune', rsync_plugin.git_depth.to_s

        execute :git, :fetch, '--quiet --tags' if !!fetch(:rsync_checkout_tag, false)

        execute :git, :reset, '--quiet', '--hard', rsync_plugin.rsync_target.to_s

        if fetch(:enable_git_submodules)
          if fetch(:reset_git_submodules_before_update)
            execute :git, :submodule, :foreach, "'git reset --hard HEAD && git clean -qfd && git fetch -t'"
          end

          execute :git, :submodule, :update
        end
      end
    end
  end

  # Remote Cache -> Remote Release
  desc 'Copy the code to the releases directory.'
  task create_release: %w[rsync] do
    # Skip copying if we've already synced straight to the release directory.
    next unless fetch(:rsync_cache)
    next unless has_roles?

    copy = %(#{fetch(:rsync_copy)} "#{rsync_plugin.rsync_cache}/" "#{release_path}/")
    on release_roles(:all) do |_host|
      execute copy
    end
  end
end
