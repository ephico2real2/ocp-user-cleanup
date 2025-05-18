#!/usr/bin/env python3
"""
Example script demonstrating how to use the 'oc' CLI commands through Python's subprocess module.
This script includes examples of:
1. Running oc commands and capturing output
2. Error handling
3. A basic user creation function
"""

import subprocess
import json
import sys
import logging
import argparse
from typing import Dict, List, Tuple, Optional, Any


# Set up logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


def run_oc_command(command: List[str]) -> Tuple[bool, str]:
    """
    Run an OpenShift (oc) command and return the result.
    
    Args:
        command: List of command parts (e.g., ["get", "users", "-o", "json"])
    
    Returns:
        Tuple of (success: bool, output: str)
    """
    full_command = ["oc"] + command
    try:
        logger.debug(f"Executing: {' '.join(full_command)}")
        result = subprocess.run(
            full_command,
            capture_output=True,
            text=True,
            check=True
        )
        return True, result.stdout
    except subprocess.CalledProcessError as e:
        logger.error(f"Command failed: {' '.join(full_command)}")
        logger.error(f"Error: {e.stderr.strip()}")
        return False, e.stderr
    except Exception as e:
        logger.error(f"Exception while running command: {e}")
        return False, str(e)


def is_logged_in() -> bool:
    """Check if user is logged in to OpenShift cluster."""
    success, _ = run_oc_command(["whoami"])
    return success


def get_users() -> List[Dict[str, Any]]:
    """
    Get a list of all users in the cluster.
    
    Returns:
        List of user objects
    """
    success, output = run_oc_command(["get", "users", "-o", "json"])
    if not success:
        logger.error("Failed to get users")
        return []
    
    try:
        data = json.loads(output)
        return data.get('items', [])
    except json.JSONDecodeError:
        logger.error("Failed to parse user data as JSON")
        return []


def create_user(username: str, groups: Optional[List[str]] = None) -> bool:
    """
    Create a new user in OpenShift.
    
    Args:
        username: The username to create
        groups: Optional list of groups to add the user to
    
    Returns:
        True if successful, False otherwise
    """
    # Create the user
    success, output = run_oc_command(["create", "user", username])
    if not success:
        logger.error(f"Failed to create user '{username}': {output}")
        return False
    
    logger.info(f"User '{username}' created successfully")
    
    # Add the user to groups if specified
    if groups:
        for group in groups:
            # Check if group exists, create if it doesn't
            group_success, _ = run_oc_command(["get", "group", group])
            if not group_success:
                logger.info(f"Group '{group}' doesn't exist, creating it")
                create_group_success, _ = run_oc_command(["adm", "groups", "new", group])
                if not create_group_success:
                    logger.warning(f"Failed to create group '{group}'")
                    continue
            
            # Add user to group
            add_success, _ = run_oc_command(["adm", "groups", "add-users", group, username])
            if add_success:
                logger.info(f"Added user '{username}' to group '{group}'")
            else:
                logger.warning(f"Failed to add user '{username}' to group '{group}'")
    
    return True


def delete_user(username: str) -> bool:
    """
    Delete a user from OpenShift.
    
    Args:
        username: The username to delete
    
    Returns:
        True if successful, False otherwise
    """
    success, output = run_oc_command(["delete", "user", username])
    if not success:
        logger.error(f"Failed to delete user '{username}': {output}")
        return False
    
    logger.info(f"User '{username}' deleted successfully")
    return True


def get_groups() -> List[Dict[str, Any]]:
    """
    Get a list of all groups in the cluster.
    
    Returns:
        List of group objects
    """
    success, output = run_oc_command(["get", "groups", "-o", "json"])
    if not success:
        logger.error("Failed to get groups")
        return []
    
    try:
        data = json.loads(output)
        return data.get('items', [])
    except json.JSONDecodeError:
        logger.error("Failed to parse group data as JSON")
        return []


def add_user_to_group(username: str, group: str) -> bool:
    """
    Add a user to a specific group in OpenShift.
    
    Args:
        username: The username to add to the group
        group: The group to add the user to
    
    Returns:
        True if successful, False otherwise
    """
    # Check if group exists, create if it doesn't
    group_success, _ = run_oc_command(["get", "group", group])
    if not group_success:
        logger.info(f"Group '{group}' doesn't exist, creating it")
        create_group_success, _ = run_oc_command(["adm", "groups", "new", group])
        if not create_group_success:
            logger.error(f"Failed to create group '{group}'")
            return False
    
    # Add user to group
    add_success, output = run_oc_command(["adm", "groups", "add-users", group, username])
    if not add_success:
        logger.error(f"Failed to add user '{username}' to group '{group}': {output}")
        return False
    
    logger.info(f"Added user '{username}' to group '{group}'")
    return True


def check_connection() -> bool:
    """
    Check if connection to OpenShift cluster is working.
    
    Returns:
        True if connected, False otherwise
    """
    if not is_logged_in():
        logger.error("Not logged in to OpenShift cluster. Run 'oc login' first.")
        return False
    
    success, output = run_oc_command(["project"])
    if not success:
        logger.error("Failed to get current project")
        return False
    
    logger.info(f"Connected to OpenShift. Current project: {output.strip()}")
    return True


def setup_argparse() -> argparse.ArgumentParser:
    """
    Set up command line argument parsing.
    
    Returns:
        ArgumentParser object configured with all needed arguments
    """
    parser = argparse.ArgumentParser(
        description="OpenShift CLI operations through Python",
        epilog="Examples:\n"
               "  ./oc_example.py list-users\n"
               "  ./oc_example.py create-user testuser\n"
               "  ./oc_example.py add-to-group testuser developers\n"
               "  ./oc_example.py delete-user testuser",
        formatter_class=argparse.RawDescriptionHelpFormatter
    )
    
    subparsers = parser.add_subparsers(dest='command', help='Operation to perform')
    
    # list-users command
    list_users_parser = subparsers.add_parser('list-users', help='List all users in the OpenShift cluster')
    
    # create-user command
    create_user_parser = subparsers.add_parser('create-user', help='Create a new user in the OpenShift cluster')
    create_user_parser.add_argument('username', help='Username of the user to create')
    create_user_parser.add_argument('--groups', nargs='*', help='List of groups to add the user to')
    
    # delete-user command
    delete_user_parser = subparsers.add_parser('delete-user', help='Delete a user from the OpenShift cluster')
    delete_user_parser.add_argument('username', help='Username of the user to delete')
    
    # add-to-group command
    add_to_group_parser = subparsers.add_parser('add-to-group', 
                                               help='Add a user to a specific group')
    add_to_group_parser.add_argument('username', help='Username of the user to add to the group')
    add_to_group_parser.add_argument('group', help='Group to add the user to')
    
    # list-groups command
    list_groups_parser = subparsers.add_parser('list-groups', help='List all groups in the OpenShift cluster')
    
    return parser


def main():
    """Main function providing a command-line interface for OpenShift operations."""
    parser = setup_argparse()
    args = parser.parse_args()
    
    # Check connection to OpenShift
    if not check_connection():
        sys.exit(1)
    
    # Handle different commands
    if args.command == 'list-users':
        logger.info("Getting list of users...")
        users = get_users()
        logger.info(f"Found {len(users)} users")
        
        if users:
            logger.info("User list:")
            for user in users:
                user_name = user.get('metadata', {}).get('name', 'Unknown')
                logger.info(f"- {user_name}")
    
    elif args.command == 'create-user':
        username = args.username
        groups = args.groups if args.groups else None
        
        logger.info(f"Creating user '{username}'...")
        if create_user(username, groups=groups):
            logger.info(f"Successfully created user '{username}'")
            
            # Verify the user was created
            users_after = get_users()
            user_created = any(
                user.get('metadata', {}).get('name') == username 
                for user in users_after
            )
            
            if user_created:
                logger.info(f"Verified user '{username}' exists in the system")
            else:
                logger.warning(f"User '{username}' was not found after creation")
        else:
            logger.error(f"Failed to create user '{username}'")
    
    elif args.command == 'delete-user':
        username = args.username
        logger.info(f"Deleting user '{username}'...")
        
        if delete_user(username):
            logger.info(f"Successfully deleted user '{username}'")
        else:
            logger.error(f"Failed to delete user '{username}'")
    
    elif args.command == 'add-to-group':
        username = args.username
        group = args.group
        
        logger.info(f"Adding user '{username}' to group '{group}'...")
        if add_user_to_group(username, group):
            logger.info(f"Successfully added user '{username}' to group '{group}'")
        else:
            logger.error(f"Failed to add user '{username}' to group '{group}'")
    
    elif args.command == 'list-groups':
        logger.info("Getting list of groups...")
        groups = get_groups()
        logger.info(f"Found {len(groups)} groups")
        
        if groups:
            logger.info("Group list:")
            for group in groups:
                group_name = group.get('metadata', {}).get('name', 'Unknown')
                users = group.get('users', [])
                logger.info(f"- {group_name} (Users: {len(users)})")
    
    else:
        logger.error("No command specified")
        parser.print_help()


if __name__ == "__main__":
    main()

