require 'capistrano/scm/plugin'

class Capistrano::SCM::Rsync < Capistrano::SCM::Plugin
  def set_defaults
    set_if_empty :rsync_options, [
      '--archive'
    ]
    set_if_empty :rsync_copy, 'rsync --archive --acls --xattrs'

    # Sparse checkout allows to checkout only part of the repository
    set_if_empty :rsync_sparse_checkout, []

    # Merely here for backward compatibility reasons
    set_if_empty :rsync_checkout_tag, false

    # Option states what to checkout
    set_if_empty :rsync_checkout, -> { fetch(:rsync_checkout_tag, false) ? 'tag' : 'branch' }

    # You may not need the whole history, put to false to get it whole
    set_if_empty :rsync_depth, 1

    # Stage is used on your local machine for rsyncing from.
    set_if_empty :rsync_stage, 'tmp/deploy'

    # Cache is used on the server to copy files to from to the release directory.
    # Saves you rsyncing your whole app folder each time.  If you nil rsync_cache,
    # Capistrano::Rsync will sync straight to the release path.
    set_if_empty :rsync_cache, 'shared/deploy'

    set_if_empty :rsync_target_dir, '.'

    # Creates opportunity to define remote other than origin
    set_if_empty :git_remote, 'origin'

    set_if_empty :enable_git_submodules, false

    set_if_empty :reset_git_submodules_before_update, false

    set_if_empty :bypass_git_clone, false
  end

  def register_hooks
    after 'deploy:new_release_path', 'rsync:create_release'
    before 'deploy:check', 'rsync:check'
    before 'deploy:set_current_revision', 'rsync:set_current_revision'
  end

  def define_tasks
    eval_rakefile File.expand_path('tasks/scm-rsync.rake', __dir__)
  end

  def rsync_cache
    cache = fetch(:rsync_cache)
    cache = deploy_to + '/' + cache if cache && cache !~ %r{^/}
    cache
  end

  def rsync_target
    case fetch(:rsync_checkout).to_s
    when 'tag'
      "tags/#{fetch(:branch)}"
    when 'revision'
      fetch(:branch)
    else
      [fetch(:git_remote).to_s, fetch(:branch).to_s].join('/')
    end
  end

  def rsync_branch
    if fetch(:rsync_checkout) == 'tag'
      "tags/#{fetch(:branch)}"
    else
      fetch(:branch)
    end
  end

  def git_depth
    !!fetch(:rsync_depth, false) ? "--depth=#{fetch(:rsync_depth)}" : ''
  end

  def git_depth_clone
    !!fetch(:rsync_depth, false) ? "--depth=#{fetch(:rsync_depth)} --no-single-branch" : ''
  end
end
