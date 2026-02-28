import discord
from discord.ext import commands
from discord import app_commands
import docker
import logging

import traceback

class Commands(commands.Cog):
    def __init__(self, bot):
        self.bot = bot
        self.logger = logging.getLogger('corekeeper_bot')
        try:
            # Connect using standard environment (Unix socket)
            self.docker_client = docker.from_env()
        except Exception as e:
            self.logger.error(f"Failed to connect to Docker Daemon: {e}")
            self.logger.error(traceback.format_exc())
            self.docker_client = None

    @app_commands.command(name="gameid", description="Get the current Core Keeper Game ID")
    async def gameid(self, interaction: discord.Interaction):
        await interaction.response.defer(ephemeral=True)
        
        if not self.docker_client:
            await interaction.followup.send("⚠️ Internal Error: Bot cannot access Docker Daemon.", ephemeral=True)
            return

        try:
            container = self.docker_client.containers.get("core-keeper-dedicated")
            
            # Execute command inside container
            # We look for GameID.txt in the app directory where it is generated
            result = container.exec_run("cat /home/steam/core-keeper-dedicated/GameID.txt")
            
            if result.exit_code == 0:
                game_id = result.output.decode('utf-8').strip()
                if game_id:
                    await interaction.followup.send(f"**Game ID:** `{game_id}`")
                else:
                    await interaction.followup.send("⚠️ Game ID file is empty. The server might be starting up.", ephemeral=True)
            else:
                await interaction.followup.send("⚠️ Game ID file not found. Is the server running?", ephemeral=True)

        except docker.errors.NotFound:
            await interaction.followup.send("🔴 Server container not found.", ephemeral=True)
        except Exception as e:
            self.logger.error(f"Error fetching Game ID: {e}")
            await interaction.followup.send("⚠️ Failed to retrieve Game ID.", ephemeral=True)

async def setup(bot):
    await bot.add_cog(Commands(bot))
