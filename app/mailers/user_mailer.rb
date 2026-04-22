class UserMailer < ApplicationMailer
  # Subject can be set in your I18n file at config/locales/en.yml
  # with the following lookup:
  #
  #   en.user_mailer.otp_email.subject
  #
  def otp_email(user)
    @user = user
    mail to: user.email, subject: "Your One-Time Password"
  end
end
