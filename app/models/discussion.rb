class Discussion < ActiveRecord::Base
  attr_accessor :recipient_tokens, :recipient_ids
  attr_reader :recipient_ids

  # paginates_per 10

  # creater
  has_many :messages, :dependent => :destroy

  # participants of discussion (speakers)
  has_many :speakers, :dependent => :destroy
  has_many :users, :through => :speakers

  # marks about read/unread
  scope :unread_for, (lambda do |user_or_user_id|
    user = user_or_user_id.is_a?(User) ? user_or_user_id.id : user_or_user_id
    joins(:speakers).where("discussions.updated_at >= speakers.updated_at AND speakers.user_id = ?", user)
  end)

  accepts_nested_attributes_for :messages

  validate :check_that_has_at_least_two_users # don't allow to create discussion, if there is no creator

  # mark as read
  after_save(:on => :create) do
    if recipient_ids.kind_of?(Array)
      recipient_ids.uniq!
      recipient_ids.each do |id|
        recipient = User.find(id)
        add_speaker(recipient) if recipient
      end
    end
  end

  def recipient_tokens=(ids)
    self.recipient_ids = ids
  end

  def add_recipient_token id
    self.recipient_ids << id if self.recipient_ids
  end

  def add_speaker(user)
    raise ArgumentError, "You can add speaker only to existing Discussion. Save your the Discussion object firstly" if new_record?
    Speaker.create(:discussion => self, :user => user)
  end

  def remove_speaker(user)
    speaker = find_speaker_by_user(user)
    speaker.destroy if speaker
  end

  def user_invited_at(user)
    speaker = find_speaker_by_user(user)
    speaker.created_at
  end

  def can_participate?(user)
    speaker = find_speaker_by_user(user)
    speaker ? true : false
  end

  # don't allow to create discussion with user, if discussion with this user already exists
  # TODO move to separated method and return boolean value
  def self.find_between_users(user, user2)
    dialog = nil
    discussions = self.joins(:speakers).includes(:users).where("speakers.user_id = ?", user.id)
    Rails.logger.info "Searching for ids: #{user.id}, #{user2.id}"
    discussions.each do |discussion|
      dialog = discussion if discussion.private? && ((discussion.users.first == user && discussion.users.last == user2) || (discussion.users.first == user2 && discussion.users.last == user))
    end
    dialog
  end

  # private/group discussion
  def private?
    self.users.size <= 2
  end

  def unread_for?(user)
    speaker = find_speaker_by_user(user)
    if speaker
      self.updated_at >= speaker.updated_at
    else
      true
    end
  end

  def mark_as_read_for(user)
    speaker = Speaker.find_or_create_by_user_id_and_discussion_id(user.id, self.id)
    # flag.update_attributes(:updat => Time.zone.now)
    speaker.touch
  end
  
  def find_speaker_by_user user
    Speaker.find_by_discussion_id_and_user_id(self.id, user.id)
  end
  
  private

  def check_that_has_at_least_two_users
    errors.add :recipient_tokens, t("inboxes.discussions.choose_at_least_one_recipient") if !self.recipient_ids || self.recipient_ids.size < 2
  end

end