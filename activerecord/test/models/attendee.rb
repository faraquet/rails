# frozen_string_literal: true

class Attendee < ActiveRecord::Base
  belongs_to :event

  validates :name, presence: true
  validates :ticket_price, presence: true
  validates :registration_date, presence: true
end
