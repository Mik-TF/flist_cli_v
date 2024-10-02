import os
import net.http
import term
import json

const (
    token_file       = os.join_path(os.home_dir(), '.config', 'tfhubtoken')
    binary_location  = if os.user_os() == 'windows' {
        'C:\\Program Files\\flist\\flist.exe'
    } else {
        '/usr/local/bin/flist'
    }
)

struct FlistItem {
    name string
}

struct Payload {
    username string
}

struct Response {
    payload Payload
}

fn error_message(msg string) {
    println(term.bold(term.red('Error: ')) + msg)
    println(term.yellow('Run \'flist help\' for usage information.'))
}

fn install() {
    println('Installing Flist CLI...')
    current_exe := os.executable()
    if os.exists(current_exe) {
        os.mkdir_all(os.dir(binary_location)) or { panic(err) }
        os.cp(current_exe, binary_location) or { panic(err) }
        os.chmod(binary_location, 0o755) or { panic(err) }
        println('Flist CLI has been installed to ' + binary_location)
        println('You can now use it by running \'flist help\'')
    } else {
        error_message('Cannot find the executable file')
        exit(1)
    }
}

fn uninstall() {
    println('Uninstalling Flist CLI...')
    if os.exists(binary_location) {
        os.rm(binary_location) or { panic(err) }
        println('Flist CLI has been removed from ' + binary_location)
    } else {
        println('Flist CLI is not installed at ' + binary_location)
    }
}

fn login() {
    mut token_exists := os.exists(token_file)
    mut docker_logged_in := false

    docker_user_result := os.execute('docker system info | grep \'Username\' | cut -d \' \' -f 3')
    if docker_user_result.exit_code == 0 && docker_user_result.output.trim_space() != '' {
        docker_logged_in = true
    }

    if token_exists && docker_logged_in {
        println('You are already logged in to Docker Hub and your Flist Hub token is present.')
        return
    }

    if !token_exists {
        tfhub_token := os.input('Please enter your tfhub token: ')
        os.write_file(token_file, tfhub_token) or { panic(err) }
        println('Token saved in ' + token_file)
    } else {
        println('Your Flist Hub token is already saved.')
    }

    if !docker_logged_in {
        println('Logging in to Docker Hub...')
        exit_code := os.system('docker login')
        if exit_code == 0 {
            println('Successfully logged in to Docker Hub.')
        } else {
            error_message('Failed to log in to Docker Hub.')
            return
        }
    } else {
        println('Already logged in to Docker Hub.')
    }

    println('Login process completed.')
}

fn logout() {
    if !os.exists(token_file) {
        error_message('You are not logged in.')
        return
    }

    os.rm(token_file) or { panic(err) }

    println('Logging out from Docker Hub...')
    exit_code := os.system('docker logout')
    if exit_code != 0 {
        error_message('Failed to log out from Docker Hub.')
    }

    println('You are now logged out of Docker Hub and your Flist Hub token has been removed.')
}

fn push(tag string) {
    println('Logging in to Docker Hub...')
    if os.system('sudo docker login') != 0 {
        error_message('Failed to log in to Docker Hub.')
        exit(1)
    }

    docker_user_result := os.execute('sudo docker system info | grep \'Username\' | cut -d \' \' -f 3')
    if docker_user_result.exit_code != 0 || docker_user_result.output.trim_space() == '' {
        error_message('Failed to get Docker username. Please ensure you are logged in to Docker.')
        exit(1)
    }

    docker_user := docker_user_result.output.trim_space()
    println('Docker username: $docker_user')

    full_tag := '${docker_user}/${tag}'

    tfhub_token := os.read_file(token_file) or {
        error_message('No token found. Please run \'flist login\' first.')
        exit(1)
    }

    println('Starting Docker build')
    if os.system('sudo docker buildx build -t ${full_tag} .') != 0 {
        error_message('Docker build failed')
        exit(1)
    }

    println('Finished local Docker build, now pushing to Docker Hub')
    if os.system('sudo docker push ${full_tag}') != 0 {
        error_message('Docker push failed')
        exit(1)
    }

    println('Converting Docker image to flist now...')

    url := 'https://hub.grid.tf/api/flist/me/docker'
    data := 'image=$full_tag'

    mut config := http.FetchConfig{
        url: url
        method: .post
        data: data
        header: http.new_header(
            key: .authorization
            value: 'bearer $tfhub_token'
        )
    }

    config.header.add_custom('Content-Type', 'application/x-www-form-urlencoded') or {
        eprintln('Add custom failed: $err')
        exit(1)
    }

    response := http.fetch(config) or {
        eprintln('HTTP POST request failed: $err')
        exit(1)
    }

    if response.status_code == 200 {
        println('Request successful. Response body:')
        println(response.body)

        // Get the hub username to construct the flist URL
        hub_user := get_hub_username(tfhub_token) or {
            error_message('Failed to get hub username')
            exit(1)
        }

        // Construct the flist URL
        flist_name := tag.replace(':', '-') + '.flist'
        flist_url := 'https://hub.grid.tf/$hub_user/$flist_name'
        
        println('\nFlist URL:')
        println(flist_url)
    } else {
        eprintln('Request failed with status code: ${response.status_code}')
        eprintln('Response body:')
        eprintln(response.body)
        exit(1)
    }
}

fn delete(flist_name string) {
    tfhub_token := os.read_file(token_file) or {
        error_message('No token found. Please run \'flist login\' first.')
        exit(1)
    }

    println('Deleting flist: ' + flist_name)
    url := 'https://hub.grid.tf/api/flist/me/' + flist_name
    config := http.FetchConfig{
        url: url
        method: .delete
        header: http.new_header(key: .authorization, value: 'bearer ' + tfhub_token)
    }

    response := http.fetch(config) or {
        error_message('Failed to send delete request: ' + err.msg())
        exit(1)
    }

    if response.status_code == 200 {
        println('Deletion request sent successfully.')
    } else {
        error_message('Deletion request failed with status code: ' + response.status_code.str())
    }
}

fn rename(flist_name string, new_flist_name string) {
    tfhub_token := os.read_file(token_file) or {
        error_message('No token found. Please run \'flist login\' first.')
        exit(1)
    }

    println('Renaming flist: ' + flist_name + ' to ' + new_flist_name)
    url := 'https://hub.grid.tf/api/flist/me/' + flist_name + '/rename/' + new_flist_name
    config := http.FetchConfig{
        url: url
        method: .get
        header: http.new_header(key: .authorization, value: 'bearer ' + tfhub_token)
    }

    response := http.fetch(config) or {
        error_message('Failed to send rename request: ' + err.msg())
        exit(1)
    }

    if response.status_code == 200 {
        println('Rename request sent successfully.')
    } else {
        error_message('Rename request failed with status code: ' + response.status_code.str())
    }
}

fn get_hub_username(tfhub_token string) ?string {
    url := 'https://hub.grid.tf/api/flist/me'

    config := http.FetchConfig{
        url: url
        method: .get
        header: http.new_header(
            key: .authorization
            value: 'bearer $tfhub_token'
        )
    }

    response := http.fetch(config) or {
        error_message('Failed to fetch hub username: $err')
        return none
    }

    if response.status_code != 200 {
        error_message('Failed to fetch hub username. Status code: $response.status_code')
        return none
    }

    parsed_response := json.decode(Response, response.body) or {
        error_message('Failed to parse JSON response: $err')
        return none
    }

    if parsed_response.payload.username != '' {
        return parsed_response.payload.username
    }

    error_message('Username not found in response')
    return none
}

fn ls(show_url bool) {
    tfhub_token := os.read_file(token_file) or {
        error_message('No token found. Please run \'flist login\' first.')
        exit(1)
    }

    hub_user := get_hub_username(tfhub_token) or {
        error_message('Failed to get hub username')
        exit(1)
    }

    url := 'https://hub.grid.tf/api/flist/$hub_user'

    config := http.FetchConfig{
        url: url
        method: .get
        header: http.new_header(
            key: .authorization
            value: 'bearer $tfhub_token'
        )
    }

    response := http.fetch(config) or {
        error_message('Failed to fetch data: $err')
        exit(1)
    }

    if response.status_code != 200 {
        error_message('Failed to fetch data. Status code: $response.status_code')
        exit(1)
    }

    data := json.decode([]FlistItem, response.body) or {
        error_message('Failed to parse JSON: $err')
        exit(1)
    }

    println('Flists for user $hub_user:')
    for item in data {
        if show_url {
            println('https://hub.grid.tf/$hub_user/${item.name}')
        } else {
            println(item.name)
        }
    }
}

fn help() {
    println(term.bold(term.green('\n Welcome to the Flist CLI!')))
    println('This tool turns Dockerfiles and Docker images directly into Flist on the TF Flist Hub, passing by the Docker Hub.\n')
    println(term.bold('Available commands:'))
    println(term.blue('  install   ') + '- Install the Flist CLI')
    println(term.blue('  uninstall ') + '- Uninstall the Flist CLI')
    println(term.blue('  login     ') + '- Log in to Docker Hub and save the Flist Hub token')
    println(term.blue('  logout    ') + '- Log out of Docker Hub and remove the Flist Hub token')
    println(term.blue('  push      ') + '- Build and push a Docker image to Docker Hub, then convert and push it as an flist to Flist Hub')
    println(term.blue('  delete    ') + '- Delete an flist from Flist Hub')
    println(term.blue('  rename    ') + '- Rename an flist in Flist Hub')
    println(term.blue('  ls        ') + '- List all flists of the current user')
    println(term.blue('  ls url    ') + '- List all flists of the current user with full URLs')
    println(term.blue('  help      ') + '- Display this help message\n')
    println(term.bold('Usage:'))
    println('  flist install')
    println('  flist uninstall')
    println('  flist login')
    println('  flist logout')
    println('  flist push <image>:<tag>')
    println('  flist delete <flist_name>')
    println('  flist rename <flist_name> <new_flist_name>')
    println('  flist ls')
    println('  flist ls url')
    println('  flist help')
}

fn main() {
    if os.args.len == 1 {
        help()
        return
    }

    match os.args[1] {
        'install' { install() }
        'uninstall' { uninstall() }
        'push' {
            if os.args.len == 3 {
                push(os.args[2])
            } else {
                error_message('Incorrect number of arguments for \'push\'.')
                exit(1)
            }
        }
        'login' { login() }
        'logout' { logout() }
        'delete' {
            if os.args.len == 3 {
                delete(os.args[2])
            } else {
                error_message('Incorrect number of arguments for \'delete\'.')
                exit(1)
            }
        }
        'rename' {
            if os.args.len == 4 {
                rename(os.args[2], os.args[3])
            } else {
                error_message('Incorrect number of arguments for \'rename\'.')
                exit(1)
            }
        }
        'ls' {
            if os.args.len == 2 {
                ls(false)
            } else if os.args.len == 3 && os.args[2] == 'url' {
                ls(true)
            } else {
                error_message('Incorrect usage of \'ls\'. Use \'ls\' or \'ls url\'.')
                exit(1)
            }
        }
        'help' { help() }
        else {
            error_message('Unknown command: ' + os.args[1])
            exit(1)
        }
    }
}