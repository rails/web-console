# frozen_string_literal: true

require "test_helper"

module WebConsole
  class PermissionsTest < ActiveSupport::TestCase
    test "localhost is always allowed" do
      permissions = permit("8.8.8.8")

      assert_includes permissions, "127.0.0.1"
      assert_includes permissions, "::1"
      assert_includes permissions, "::ffff:127.0.0.1"
    end

    test "permits single IPs" do
      permissions = permit("8.8.8.8")

      assert_includes permissions, "8.8.8.8"
    end

    test "permits whole networks" do
      permissions = permit("172.16.0.0/12")

      1.upto(255).each do |n|
        assert_includes permissions, "172.16.0.#{n}"
      end
    end

    test "permits multiple networks" do
      permissions = permit %w(172.16.0.0/12 192.168.0.0/16)

      1.upto(255).each do |n|
        assert_includes permissions, "172.16.0.#{n}"
        assert_includes permissions, "192.168.0.#{n}"
      end
    end

    test "ignores UNIX socket" do
      permissions = permit("8.8.8.8")

      assert_not_includes permissions, "unix:"
    end

    test "human readable presentation" do
      assert_includes permit.to_s, "127.0.0.0/127.255.255.255, ::1, ::ffff:127.0.0.0/::ffff:127.255.255.255"
    end

    private

      def permit(*args)
        Permissions.new(*args)
      end
  end
end
