class CreateUsers < ActiveRecord::Migration[7.0]
  def change
    create_table :users, id: :uuid do |t|
      t.string :firstname
      t.string :lastname
      t.boolean :isadmin, null: false, default: false

      t.timestamps
    end
  end
end
